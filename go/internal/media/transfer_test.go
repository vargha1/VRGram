package media

import (
	"path/filepath"
	"testing"
)

func TestTransferStore_Create(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "transfers.db")
	store, err := NewTransferStore(dbPath)
	if err != nil {
		t.Fatalf("NewTransferStore: %v", err)
	}
	defer store.Close()

	entry := &TransferEntry{
		ID:          "test-transfer-1",
		PeerPubkey:  "peer123",
		FileName:    "photo.jpg",
		MimeType:    "image/jpeg",
		FileSize:    1024,
		Status:      TransferQueued,
		Progress:    0,
		CreatedAt:   1000,
	}
	err = store.Create(entry)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
}

func TestTransferStore_UpdateAndGet(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "transfers.db")
	store, _ := NewTransferStore(dbPath)
	defer store.Close()

	store.Create(&TransferEntry{ID: "t1", Status: TransferQueued, CreatedAt: 1000})
	store.Update("t1", TransferUploading, 50, 10)

	got, err := store.Get("t1")
	if err != nil { t.Fatalf("Get: %v", err) }
	if got.Status != TransferUploading { t.Errorf("expected Uploading, got %v", got.Status) }
	if got.Progress != 50 { t.Errorf("expected progress 50, got %d", got.Progress) }
	if got.ChunksSent != 10 { t.Errorf("expected chunksSent 10, got %d", got.ChunksSent) }
}

func TestTransferStore_Persistence(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "transfers.db")
	store, _ := NewTransferStore(dbPath)
	store.Create(&TransferEntry{ID: "persist-test", Status: TransferQueued, CreatedAt: 2000})
	store.Close()

	store2, _ := NewTransferStore(dbPath)
	defer store2.Close()
	got, _ := store2.Get("persist-test")
	if got == nil { t.Fatal("expected entry after reopen") }
	if got.Status != TransferQueued { t.Errorf("expected Queued, got %v", got.Status) }
}

func TestTransferStore_ListPending(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "transfers.db")
	store, _ := NewTransferStore(dbPath)
	defer store.Close()

	store.Create(&TransferEntry{ID: "a", Status: TransferQueued, CreatedAt: 100})
	store.Create(&TransferEntry{ID: "b", Status: TransferComplete, CreatedAt: 200})
	store.Create(&TransferEntry{ID: "c", Status: TransferUploading, CreatedAt: 300})

	pending, _ := store.ListPending()
	if len(pending) != 2 { t.Fatalf("expected 2 pending, got %d", len(pending)) }
}
