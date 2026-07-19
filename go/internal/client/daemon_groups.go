package client

import (
	"context"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/user/dns-transport/internal/crypto"
	pb "github.com/user/dns-transport/pkg/relaypb"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// CreateGroup creates a new chat group, generates a group key, and distributes it to all members.
func (d *Daemon) CreateGroup(ctx context.Context, req *pb.CreateGroupRequest) (*pb.CreateGroupResponse, error) {
	groupKey, err := crypto.GenerateGroupKey()
	if err != nil {
		return nil, status.Error(codes.Internal, "generate group key failed")
	}

	groupID := fmt.Sprintf("g%d", time.Now().UnixNano())
	myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)

	members := make(map[string]*GroupMember)
	members[myPubkey] = &GroupMember{Pubkey: myPubkey, Nickname: req.Name + "_admin", Role: "admin"}
	for _, mpk := range req.MemberPubkeys {
		members[mpk] = &GroupMember{Pubkey: mpk, Nickname: "", Role: "member"}
	}

	group := &Group{
		GroupID:     groupID,
		Name:        req.Name,
		AdminPubkey: myPubkey,
		Members:     members,
		GroupKey:    groupKey,
		KeyEpoch:    1,
	}
	d.groupsMu.Lock()
	d.groups[groupID] = group
	d.groupsMu.Unlock()
	d.saveGroups()

	// Distribute group key to each member via pairwise ECDH
	for pubkeyB64 := range members {
		if pubkeyB64 == myPubkey {
			continue
		}
		pubkey, err := base64.StdEncoding.DecodeString(pubkeyB64)
		if err != nil {
			continue
		}
		ss, err := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
		if err != nil {
			continue
		}
		distribution := fmt.Sprintf(`{"type":"group_key","group_id":"%s","group_key_b64":"%s","key_epoch":%d,"name":"%s"}`,
			groupID, base64.StdEncoding.EncodeToString(groupKey), uint64(1), req.Name)
		ciphertext, _, _ := crypto.EncryptMessage(ss, []byte(distribution))
		d.engine.SendMessage(context.Background(), ciphertext, pubkeyB64)
	}

	return &pb.CreateGroupResponse{GroupId: groupID}, nil
}

// ListGroups returns all groups this node is a member of.
func (d *Daemon) ListGroups(ctx context.Context, req *pb.Empty) (*pb.ListGroupsResponse, error) {
	d.groupsMu.RLock()
	defer d.groupsMu.RUnlock()
	var pbGroups []*pb.GroupInfo
	for _, g := range d.groups {
		var pbMembers []*pb.GroupMember
		for _, m := range g.Members {
			pbMembers = append(pbMembers, &pb.GroupMember{
				Pubkey:   m.Pubkey,
				Nickname: m.Nickname,
				Role:     m.Role,
			})
		}
		pbGroups = append(pbGroups, &pb.GroupInfo{
			GroupId:     g.GroupID,
			Name:        g.Name,
			AdminPubkey: g.AdminPubkey,
			Members:     pbMembers,
			KeyEpoch:    g.KeyEpoch,
		})
	}
	return &pb.ListGroupsResponse{Groups: pbGroups}, nil
}

// LeaveGroup removes the current node from a group. If admin leaves, reassigns admin.
// If no members remain, the group is deleted.
func (d *Daemon) LeaveGroup(ctx context.Context, req *pb.LeaveGroupRequest) (*pb.Empty, error) {
	d.groupsMu.Lock()
	group, ok := d.groups[req.GroupId]
	if !ok {
		d.groupsMu.Unlock()
		return nil, status.Errorf(codes.NotFound, "group not found: %s", req.GroupId)
	}
	myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
	delete(group.Members, myPubkey)
	// If admin leaves, reassign admin to first remaining member
	if group.AdminPubkey == myPubkey && len(group.Members) > 0 {
		for pubkey := range group.Members {
			group.AdminPubkey = pubkey
			group.Members[pubkey].Role = "admin"
			break
		}
	}
	// If no members left, delete the group
	if len(group.Members) == 0 {
		delete(d.groups, req.GroupId)
	}
	d.groupsMu.Unlock()
	d.saveGroups()
	return &pb.Empty{}, nil
}

// RemoveGroupMember removes a member from a group (admin only). Rotates group key.
func (d *Daemon) RemoveGroupMember(ctx context.Context, req *pb.RemoveGroupMemberRequest) (*pb.Empty, error) {
	d.groupsMu.Lock()
	group, ok := d.groups[req.GroupId]
	if !ok {
		d.groupsMu.Unlock()
		return nil, status.Errorf(codes.NotFound, "group not found: %s", req.GroupId)
	}
	myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
	if group.AdminPubkey != myPubkey {
		d.groupsMu.Unlock()
		return nil, status.Error(codes.PermissionDenied, "only admin can remove members")
	}
	if _, exists := group.Members[req.MemberPubkey]; !exists {
		d.groupsMu.Unlock()
		return nil, status.Errorf(codes.NotFound, "member not in group")
	}
	delete(group.Members, req.MemberPubkey)
	// Rotate group key since membership changed
	newKey, err := crypto.RotateGroupKey(group.GroupKey)
	if err == nil {
		group.GroupKey = newKey
		group.KeyEpoch++
	}
	d.groupsMu.Unlock()
	d.saveGroups()
	// Distribute new key to remaining members
	d.distributeGroupKey(group.GroupID)
	return &pb.Empty{}, nil
}

// distributeGroupKey sends the current group key to all members via pairwise ECDH.
func (d *Daemon) distributeGroupKey(groupID string) {
	d.groupsMu.RLock()
	group, ok := d.groups[groupID]
	d.groupsMu.RUnlock()
	if !ok {
		return
	}

	myPubkeyB64 := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
	for pubkeyB64, member := range group.Members {
		if pubkeyB64 == myPubkeyB64 {
			continue
		}
		pubkey, err := base64.StdEncoding.DecodeString(pubkeyB64)
		if err != nil {
			continue
		}
		ss, err := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
		if err != nil {
			continue
		}
		distribution := fmt.Sprintf(`{"type":"group_key","group_id":"%s","group_key_b64":"%s","key_epoch":%d}`,
			groupID, base64.StdEncoding.EncodeToString(group.GroupKey), group.KeyEpoch)
		ciphertext, _, _ := crypto.EncryptMessage(ss, []byte(distribution))
		d.engine.SendMessage(context.Background(), ciphertext, pubkeyB64)
		_ = member
	}
}
