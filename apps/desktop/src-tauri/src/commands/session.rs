use std::sync::atomic::Ordering;
use rusqlite::params;
use serde::Serialize;
use tauri::{Emitter, State};

use crate::capture::buffer;
use crate::crypto::hashing;
use crate::features::{tier1, tier2, vector::FeatureVector};
use crate::state::AppState;

#[derive(Serialize)]
pub struct StartSessionResult {
    session_id: String,
    document_id: String,
}

#[derive(Serialize)]
pub struct CheckpointResult {
    commitment_hash: String,
    sequence: i64,
    keystroke_count: u64,
}

#[tauri::command]
pub fn start_session(
    document_id: Option<String>,
    state: State<'_, AppState>,
) -> Result<StartSessionResult, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    let now = chrono::Utc::now().to_rfc3339();

    // Create or use existing document
    let doc_id = document_id.unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    // Ensure document exists
    db.execute(
        "INSERT OR IGNORE INTO documents (id, title, created_at, updated_at)
         VALUES (?1, 'Untitled', ?2, ?2)",
        params![doc_id, now],
    )
    .map_err(|e| e.to_string())?;

    // Create session
    let session_id = uuid::Uuid::new_v4().to_string();
    db.execute(
        "INSERT INTO sessions (id, document_id, started_at, status)
         VALUES (?1, ?2, ?3, 'active')",
        params![session_id, doc_id, now],
    )
    .map_err(|e| e.to_string())?;

    // Update app state
    *state.active_session_id.lock().map_err(|e| e.to_string())? = Some(session_id.clone());
    *state.active_document_id.lock().map_err(|e| e.to_string())? = Some(doc_id.clone());
    state.keystroke_count.store(0, Ordering::Relaxed);
    *state.session_start_ms.lock().map_err(|e| e.to_string())? = Some(
        chrono::Utc::now().timestamp_millis() as f64,
    );

    Ok(StartSessionResult {
        session_id,
        document_id: doc_id,
    })
}

#[tauri::command]
pub fn end_session(state: State<'_, AppState>) -> Result<(), String> {
    let session_id = {
        let guard = state.active_session_id.lock().map_err(|e| e.to_string())?;
        guard.clone().ok_or("No active session")?
    };

    let db = state.db.lock().map_err(|e| e.to_string())?;
    let now = chrono::Utc::now().to_rfc3339();
    let count = state.keystroke_count.load(Ordering::Relaxed) as i64;

    db.execute(
        "UPDATE sessions SET ended_at = ?1, keystroke_count = ?2, status = 'completed' WHERE id = ?3",
        params![now, count, session_id],
    )
    .map_err(|e| e.to_string())?;

    // Clear active session
    *state.active_session_id.lock().map_err(|e| e.to_string())? = None;
    state.keystroke_count.store(0, Ordering::Relaxed);
    *state.session_start_ms.lock().map_err(|e| e.to_string())? = None;

    Ok(())
}

#[tauri::command]
pub fn checkpoint_session(
    app: tauri::AppHandle,
    state: State<'_, AppState>,
) -> Result<CheckpointResult, String> {
    let session_id = {
        let guard = state.active_session_id.lock().map_err(|e| e.to_string())?;
        guard.clone().ok_or("No active session")?
    };

    let document_id = {
        let guard = state.active_document_id.lock().map_err(|e| e.to_string())?;
        guard.clone().ok_or("No active document")?
    };

    let db = state.db.lock().map_err(|e| e.to_string())?;

    // Get all events in the current session for feature extraction
    let events = buffer::get_events_for_window(&db, &session_id, 0.0, f64::MAX)?;

    if events.is_empty() {
        return Err("No events to checkpoint".to_string());
    }

    // Extract features
    let t1 = tier1::extract(&events);
    let t2 = tier2::extract(&events);

    let window_start = events.first().map(|e| e.timestamp).unwrap_or(0.0);
    let window_end = events.last().map(|e| e.timestamp).unwrap_or(0.0);

    let fv = FeatureVector {
        version: "0.1.0".to_string(),
        window_start_ms: window_start,
        window_end_ms: window_end,
        keystroke_count: events.len() as u32,
        tier1: t1,
        tier2: t2,
    };

    let fv_json = serde_json::to_string(&fv).map_err(|e| e.to_string())?;

    // Build commitment
    let previous_hash: Option<String> = db
        .query_row(
            "SELECT commitment_hash FROM commitment_chain
             WHERE document_id = ?1 ORDER BY sequence_num DESC LIMIT 1",
            params![document_id],
            |row| row.get(0),
        )
        .ok();

    let nonce = hashing::random_nonce();
    let commitment = hashing::commitment_hash(
        previous_hash.as_deref(),
        &nonce,
        fv_json.as_bytes(),
    );

    // Get next sequence number
    let sequence: i64 = db
        .query_row(
            "SELECT COALESCE(MAX(sequence_num), -1) + 1 FROM commitment_chain WHERE document_id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .map_err(|e| e.to_string())?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let now_str = chrono::Utc::now().to_rfc3339();
    let nonce_hex = nonce.iter().map(|b| format!("{:02x}", b)).collect::<String>();
    let fv_id = uuid::Uuid::new_v4().to_string();

    // Store feature vector and commitment in a transaction
    let tx = db.unchecked_transaction().map_err(|e| e.to_string())?;

    tx.execute(
        "INSERT INTO feature_vectors (id, session_id, window_start_ms, window_end_ms, keystroke_count, vector_json, commitment_hash, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![fv_id, session_id, window_start, window_end, events.len() as i64, fv_json, commitment, now_str],
    ).map_err(|e| e.to_string())?;

    tx.execute(
        "INSERT INTO commitment_chain (document_id, sequence_num, commitment_hash, previous_hash, nonce, timestamp_ms)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![document_id, sequence, commitment, previous_hash, nonce_hex, now_ms],
    ).map_err(|e| e.to_string())?;

    tx.commit().map_err(|e| e.to_string())?;

    // Purge ephemeral keystroke data (Section 4.2 — ephemeral zone boundary)
    let purged = buffer::purge_events_before(&db, &session_id, window_end + 1.0)?;
    let _ = app.emit("ephemeral-data-purged", serde_json::json!({
        "session_id": session_id,
        "events_deleted": purged,
    }));

    let keystroke_count = state.keystroke_count.load(Ordering::Relaxed);

    // Emit checkpoint event
    let _ = app.emit("session-checkpoint", serde_json::json!({
        "commitment_hash": commitment,
        "sequence": sequence,
        "keystroke_count": keystroke_count,
    }));

    Ok(CheckpointResult {
        commitment_hash: commitment,
        sequence,
        keystroke_count,
    })
}
