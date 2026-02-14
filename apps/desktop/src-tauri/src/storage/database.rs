use rusqlite::{Connection, Result};
use std::path::PathBuf;

fn db_path() -> PathBuf {
    let mut path = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
    path.push("speakwrite");
    std::fs::create_dir_all(&path).ok();
    path.push("data.db");
    path
}

pub fn init_database() -> Result<Connection> {
    let path = db_path();
    let conn = Connection::open(&path)?;

    conn.execute_batch("PRAGMA journal_mode=WAL;")?;
    conn.execute_batch("PRAGMA foreign_keys=ON;")?;

    run_migrations(&conn)?;

    Ok(conn)
}

fn run_migrations(conn: &Connection) -> Result<()> {
    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT 'Untitled',
            content_json TEXT,
            content_hash TEXT,
            word_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            keystroke_count INTEGER DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'active',
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ephemeral_keystrokes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            key TEXT NOT NULL,
            code TEXT NOT NULL,
            timestamp_ms REAL NOT NULL,
            shift_key INTEGER NOT NULL DEFAULT 0,
            ctrl_key INTEGER NOT NULL DEFAULT 0,
            alt_key INTEGER NOT NULL DEFAULT 0,
            meta_key INTEGER NOT NULL DEFAULT 0,
            is_repeat INTEGER NOT NULL DEFAULT 0,
            is_composing INTEGER NOT NULL DEFAULT 0,
            sequence_number INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_ephemeral_session_ts
            ON ephemeral_keystrokes(session_id, timestamp_ms);

        CREATE TABLE IF NOT EXISTS feature_vectors (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            window_start_ms REAL NOT NULL,
            window_end_ms REAL NOT NULL,
            keystroke_count INTEGER NOT NULL,
            vector_json TEXT NOT NULL,
            commitment_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS commitment_chain (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id TEXT NOT NULL,
            sequence_num INTEGER NOT NULL,
            commitment_hash TEXT NOT NULL,
            previous_hash TEXT,
            nonce TEXT NOT NULL,
            timestamp_ms INTEGER NOT NULL,
            commitment_type TEXT NOT NULL DEFAULT 'behavioral',
            content_hash TEXT,
            UNIQUE(document_id, sequence_num),
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        );
        ",
    )?;

    // Migration: add columns if they don't exist (for existing databases)
    let _ = conn.execute_batch(
        "ALTER TABLE commitment_chain ADD COLUMN commitment_type TEXT NOT NULL DEFAULT 'behavioral';",
    );
    let _ = conn.execute_batch(
        "ALTER TABLE commitment_chain ADD COLUMN content_hash TEXT;",
    );

    Ok(())
}
