use std::sync::atomic::Ordering;
use tauri::State;

use crate::capture::{buffer, events::KeystrokeEvent, validator};
use crate::state::AppState;

#[tauri::command]
pub fn record_keystroke_batch(
    events: Vec<KeystrokeEvent>,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session_id = {
        let guard = state.active_session_id.lock().map_err(|e| e.to_string())?;
        guard.clone().ok_or("No active session")?
    };

    let db = state.db.lock().map_err(|e| e.to_string())?;

    // Validate events (basic checks)
    let mut last_seq = 0u64;
    let mut last_ts = 0.0f64;
    for event in &events {
        validator::validate_event(event, last_seq, last_ts)?;
        last_seq = event.sequence_number;
        last_ts = event.timestamp;
    }

    // Insert into ephemeral buffer
    buffer::insert_event_batch(&db, &session_id, &events)?;

    // Update keystroke count
    state.keystroke_count.fetch_add(events.len() as u64, Ordering::Relaxed);

    Ok(())
}
