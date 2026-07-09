# Peer Persistence & Chat Fixes Design

**Date:** 2026-07-09
**Goal:** Fix three pre-existing bugs: peer persistence, chat list routing, per-peer message filtering.

## Bug 1: Peers delete on app close

**Root cause:** `PeerList` is an in-memory `Notifier<List<Peer>>` with `build() => []`.

**Fix:** Persist peers to JSON file in app's documents directory.

### Files
- Modify: `flutter/lib/features/peers/providers/peer_provider.dart`

### Changes
- On `build()`: load peers from `<dataDir>/peers.json`
- On `addPeer()`: save updated list to file
- On `removePeer()`: save updated list to file
- Use `dart:io` File + `dart:convert` jsonEncode/jsonDecode

## Bug 2: Chat list not working

**Root causes:**
1. `ChatListScreen` uses `Navigator.pushNamed()` but app uses GoRouter
2. Subtitle shows last message across ALL chats, not per-peer

### Files
- Modify: `flutter/lib/features/chat/screens/chat_list_screen.dart`

### Changes
- Replace `Navigator.pushNamed(context, '/chat', arguments: peers[i])` with `context.push('/chat', extra: peers[i])`
- Filter messages by `peer.pubkey` for subtitle (match `toPeer` for sent, `fromPeer` for received)
- Show per-peer last message and timestamp

## Bug 3: Messaging not working (messages mixed)

**Root cause:** `ChatScreen` shows ALL messages from `chatProvider`, not filtered by current peer.

### Files
- Modify: `flutter/lib/features/chat/providers/chat_provider.dart`
- Modify: `flutter/lib/features/chat/screens/chat_screen.dart`

### Changes
- Add `toPeer` field to `ChatMessage` (set when sending)
- `sendMessageProvider`: set `toPeer` on sent messages
- `pollMessagesProvider`: already sets `fromPeer` on received messages
- `ChatScreen`: filter `chatProvider` messages where `fromPeer == peer.pubkey || toPeer == peer.pubkey`
- Pass `peer` to `ChatScreen` (already done via route extra)

## Scope
- Peer persistence via JSON file
- Chat list routing fix
- Per-peer message filtering
- No new features, no protocol changes
