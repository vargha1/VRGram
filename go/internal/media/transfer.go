package media

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

// TransferStatus represents the state of a media transfer.
type TransferStatus int32

const (
	TransferQueued     TransferStatus = 0
	TransferEncrypting TransferStatus = 1
	TransferUploading  TransferStatus = 2
	TransferConfirming TransferStatus = 3
	TransferComplete   TransferStatus = 4
	TransferFailed     TransferStatus = 5
	TransferCancelled  TransferStatus = 6
)

func (s TransferStatus) String() string {
	switch s {
	case TransferQueued:
		return "queued"
	case TransferEncrypting:
		return "encrypting"
	case TransferUploading:
		return "uploading"
	case TransferConfirming:
		return "confirming"
	case TransferComplete:
		return "complete"
	case TransferFailed:
		return "failed"
	case TransferCancelled:
		return "cancelled"
	default:
		return fmt.Sprintf("unknown(%d)", int(s))
	}
}

// TransferEntry holds the state of a single media transfer, persisted to SQLite.
type TransferEntry struct {
	ID           string         `json:"id"`
	PeerPubkey   string         `json:"peer_pubkey"`
	FileName     string         `json:"file_name"`
	MimeType     string         `json:"mime_type"`
	FileSize     int64          `json:"file_size"`
	Status       TransferStatus `json:"status"`
	Progress     int32          `json:"progress"`
	ChunksSent   int32          `json:"chunks_sent"`
	TotalChunks  int32          `json:"total_chunks"`
	AvgChunkTime int64          `json:"avg_chunk_time_ms"`
	Error        string         `json:"error"`
	CreatedAt    int64          `json:"created_at"`
	TempFilePath string         `json:"temp_file_path"`
}

// TransferStore persists transfer state to SQLite for resume across restarts.
type TransferStore struct {
	db *sql.DB
	mu sync.Mutex
}

// NewTransferStore opens (or creates) a transfer database at dbPath.
func NewTransferStore(dbPath string) (*TransferStore, error) {
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, fmt.Errorf("create transfer dir: %w", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("open transfer db: %w", err)
	}
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS transfers (
		id TEXT PRIMARY KEY,
		peer_pubkey TEXT,
		file_name TEXT,
		mime_type TEXT,
		file_size INTEGER,
		status INTEGER,
		progress INTEGER,
		chunks_sent INTEGER,
		total_chunks INTEGER,
		avg_chunk_time_ms INTEGER,
		error TEXT,
		created_at INTEGER,
		temp_file_path TEXT
	)`)
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("create transfer table: %w", err)
	}
	return &TransferStore{db: db}, nil
}

// Create inserts a new transfer entry.
func (s *TransferStore) Create(entry *TransferEntry) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO transfers VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		entry.ID, entry.PeerPubkey, entry.FileName, entry.MimeType,
		entry.FileSize, int(entry.Status), entry.Progress,
		entry.ChunksSent, entry.TotalChunks, entry.AvgChunkTime,
		entry.Error, entry.CreatedAt, entry.TempFilePath)
	return err
}

// Update modifies the status, progress, and chunks_sent of a transfer.
func (s *TransferStore) Update(id string, status TransferStatus, progress int32, chunksSent int32) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`UPDATE transfers SET status=?, progress=?, chunks_sent=? WHERE id=?`,
		int(status), progress, chunksSent, id)
	return err
}

// Get retrieves a single transfer by ID.
func (s *TransferStore) Get(id string) (*TransferEntry, error) {
	row := s.db.QueryRow(`SELECT * FROM transfers WHERE id=?`, id)
	e := &TransferEntry{}
	var statusInt int
	err := row.Scan(&e.ID, &e.PeerPubkey, &e.FileName, &e.MimeType, &e.FileSize,
		&statusInt, &e.Progress, &e.ChunksSent, &e.TotalChunks,
		&e.AvgChunkTime, &e.Error, &e.CreatedAt, &e.TempFilePath)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	e.Status = TransferStatus(statusInt)
	return e, nil
}

// ListPending returns all transfers that haven't reached a terminal state.
func (s *TransferStore) ListPending() ([]*TransferEntry, error) {
	rows, err := s.db.Query(`SELECT * FROM transfers WHERE status IN (0,1,2,3) ORDER BY created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var entries []*TransferEntry
	for rows.Next() {
		e := &TransferEntry{}
		var statusInt int
		err := rows.Scan(&e.ID, &e.PeerPubkey, &e.FileName, &e.MimeType, &e.FileSize,
			&statusInt, &e.Progress, &e.ChunksSent, &e.TotalChunks,
			&e.AvgChunkTime, &e.Error, &e.CreatedAt, &e.TempFilePath)
		if err != nil {
			return nil, err
		}
		e.Status = TransferStatus(statusInt)
		entries = append(entries, e)
	}
	return entries, nil
}

// Close closes the database connection.
func (s *TransferStore) Close() error {
	return s.db.Close()
}

// EstimateSeconds estimates remaining transfer time based on file size and transport.
func EstimateSeconds(fileSize int64, useTCP bool) int32 {
	if useTCP {
		est := int32(fileSize / (100 * 1024) * 100 / 1000)
		if est < 5 {
			return 5
		}
		return est
	}
	// DNS: ~3s per chunk, ~75 chunks per 60KB
	est := int32(fileSize / (15 * 200) * 100 / 1000)
	if est < 10 {
		return 10
	}
	return est
}

// ensure time import is used
var _ = time.Now
