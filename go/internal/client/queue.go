package client

import (
	"database/sql"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

// QueuedMessage represents a message stored in the offline queue.
type QueuedMessage struct {
	ID        int64
	PeerKey   string
	Ciphertext []byte
	CreatedAt time.Time
	Retries   int
}

// OfflineQueue provides a SQLite-backed queue for messages that failed to send.
type OfflineQueue struct {
	db *sql.DB
}

// NewOfflineQueue opens or creates a SQLite database at the given path.
func NewOfflineQueue(path string) (*OfflineQueue, error) {
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return nil, err
	}
		_, err = db.Exec(`CREATE TABLE IF NOT EXISTS queue (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			peer_key TEXT NOT NULL,
			ciphertext BLOB NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			retries INTEGER DEFAULT 0,
			last_error TEXT
		)`)
		if err != nil {
			return nil, err
		}
		return &OfflineQueue{db: db}, nil
	}

	// Enqueue adds a new message to the queue and returns its ID.
	func (q *OfflineQueue) Enqueue(peerKey string, ciphertext []byte) (int64, error) {
		result, err := q.db.Exec(
			"INSERT INTO queue (peer_key, ciphertext) VALUES (?, ?)",
			peerKey, ciphertext)
		if err != nil {
			return 0, err
		}
		return result.LastInsertId()
	}

	// Pending returns all pending messages ordered by creation time.
	func (q *OfflineQueue) Pending() ([]QueuedMessage, error) {
		rows, err := q.db.Query(
			"SELECT id, peer_key, ciphertext, created_at, retries FROM queue ORDER BY created_at")
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var msgs []QueuedMessage
		for rows.Next() {
			var m QueuedMessage
			var createdAt string
			err := rows.Scan(&m.ID, &m.PeerKey, &m.Ciphertext, &createdAt, &m.Retries)
			if err != nil {
				return nil, err
			}
			m.CreatedAt, _ = time.Parse("2006-01-02 15:04:05", createdAt)
			msgs = append(msgs, m)
		}
		return msgs, nil
	}

// MarkFailed increments retries and records the error message.
func (q *OfflineQueue) MarkFailed(id int64, errMsg string) error {
	_, err := q.db.Exec(
		"UPDATE queue SET retries = retries + 1, last_error = ? WHERE id = ?",
		errMsg, id)
	return err
}

// Remove deletes a message from the queue by ID.
func (q *OfflineQueue) Remove(id int64) error {
	_, err := q.db.Exec("DELETE FROM queue WHERE id = ?", id)
	return err
}

// Close closes the underlying database connection.
func (q *OfflineQueue) Close() error {
	return q.db.Close()
}
