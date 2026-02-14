use rusqlite::Connection;
use std::sync::{atomic::AtomicU64, Mutex};

use crate::storage::database;

pub struct AppState {
    pub db: Mutex<Connection>,
    pub active_session_id: Mutex<Option<String>>,
    pub active_document_id: Mutex<Option<String>>,
    pub keystroke_count: AtomicU64,
    pub session_start_ms: Mutex<Option<f64>>,
}

impl AppState {
    pub fn new() -> Result<Self, String> {
        let db = database::init_database().map_err(|e| format!("DB init failed: {}", e))?;

        Ok(Self {
            db: Mutex::new(db),
            active_session_id: Mutex::new(None),
            active_document_id: Mutex::new(None),
            keystroke_count: AtomicU64::new(0),
            session_start_ms: Mutex::new(None),
        })
    }
}
