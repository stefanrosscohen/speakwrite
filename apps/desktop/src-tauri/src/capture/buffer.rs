use rusqlite::{params, Connection};

use super::events::KeystrokeEvent;

pub fn insert_event_batch(conn: &Connection, session_id: &str, events: &[KeystrokeEvent]) -> Result<usize, String> {
    let tx = conn.unchecked_transaction().map_err(|e| e.to_string())?;

    for event in events {
        tx.execute(
            "INSERT INTO ephemeral_keystrokes (
                session_id, event_type, key, code, timestamp_ms,
                shift_key, ctrl_key, alt_key, meta_key,
                is_repeat, is_composing, sequence_number
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            params![
                session_id,
                event.event_type,
                event.key,
                event.code,
                event.timestamp,
                event.shift_key as i32,
                event.ctrl_key as i32,
                event.alt_key as i32,
                event.meta_key as i32,
                event.repeat as i32,
                event.is_composing as i32,
                event.sequence_number as i64,
            ],
        )
        .map_err(|e| e.to_string())?;
    }

    tx.commit().map_err(|e| e.to_string())?;

    Ok(events.len())
}

pub fn get_events_for_window(
    conn: &Connection,
    session_id: &str,
    start_ms: f64,
    end_ms: f64,
) -> Result<Vec<KeystrokeEvent>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT event_type, key, code, timestamp_ms,
                    shift_key, ctrl_key, alt_key, meta_key,
                    is_repeat, is_composing, sequence_number
             FROM ephemeral_keystrokes
             WHERE session_id = ?1 AND timestamp_ms >= ?2 AND timestamp_ms < ?3
             ORDER BY sequence_number ASC",
        )
        .map_err(|e| e.to_string())?;

    let events = stmt
        .query_map(params![session_id, start_ms, end_ms], |row| {
            Ok(KeystrokeEvent {
                event_type: row.get(0)?,
                key: row.get(1)?,
                code: row.get(2)?,
                timestamp: row.get(3)?,
                shift_key: row.get::<_, i32>(4)? != 0,
                ctrl_key: row.get::<_, i32>(5)? != 0,
                alt_key: row.get::<_, i32>(6)? != 0,
                meta_key: row.get::<_, i32>(7)? != 0,
                repeat: row.get::<_, i32>(8)? != 0,
                is_composing: row.get::<_, i32>(9)? != 0,
                sequence_number: row.get::<_, i64>(10)? as u64,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(events)
}

pub fn purge_events_before(conn: &Connection, session_id: &str, before_ms: f64) -> Result<u64, String> {
    let deleted = conn
        .execute(
            "DELETE FROM ephemeral_keystrokes WHERE session_id = ?1 AND timestamp_ms < ?2",
            params![session_id, before_ms],
        )
        .map_err(|e| e.to_string())?;

    Ok(deleted as u64)
}
