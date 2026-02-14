use std::sync::atomic::Ordering;
use rusqlite::params;
use serde::Serialize;
use tauri::State;

use crate::state::AppState;
use crate::storage::models::CommitmentEntry;

#[derive(Serialize)]
pub struct ProofStatus {
    pub status: String,
    pub keystroke_count: u64,
    pub commitment_count: i64,
    pub session_duration_ms: f64,
    pub commitments: Vec<CommitmentEntry>,
}

#[tauri::command]
pub fn get_proof_status(state: State<'_, AppState>) -> Result<ProofStatus, String> {
    let session_id = {
        let guard = state.active_session_id.lock().map_err(|e| e.to_string())?;
        guard.clone()
    };

    let document_id = {
        let guard = state.active_document_id.lock().map_err(|e| e.to_string())?;
        guard.clone()
    };

    let keystroke_count = state.keystroke_count.load(Ordering::Relaxed);

    let session_start = {
        let guard = state.session_start_ms.lock().map_err(|e| e.to_string())?;
        *guard
    };

    let session_duration_ms = session_start
        .map(|start| chrono::Utc::now().timestamp_millis() as f64 - start)
        .unwrap_or(0.0);

    let status = if session_id.is_some() {
        "capturing".to_string()
    } else {
        "idle".to_string()
    };

    // Get commitment chain
    let commitments = if let Some(doc_id) = &document_id {
        let db = state.db.lock().map_err(|e| e.to_string())?;
        let mut stmt = db
            .prepare(
                "SELECT sequence_num, commitment_hash, previous_hash, timestamp_ms
                 FROM commitment_chain WHERE document_id = ?1
                 ORDER BY sequence_num ASC",
            )
            .map_err(|e| e.to_string())?;

        let rows: Vec<CommitmentEntry> = stmt.query_map(params![doc_id], |row| {
            Ok(CommitmentEntry {
                sequence_num: row.get(0)?,
                commitment_hash: row.get(1)?,
                previous_hash: row.get(2)?,
                timestamp_ms: row.get(3)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
        rows
    } else {
        Vec::new()
    };

    let commitment_count = commitments.len() as i64;

    Ok(ProofStatus {
        status,
        keystroke_count,
        commitment_count,
        session_duration_ms,
        commitments,
    })
}
