use rusqlite::params;
use serde::Serialize;
use tauri::State;

use crate::crypto::hashing;
use crate::state::AppState;
use crate::storage::models::Document;

#[derive(Serialize)]
pub struct DocumentListItem {
    id: String,
    title: String,
    word_count: i64,
    updated_at: String,
}

#[tauri::command]
pub fn save_document(
    title: Option<String>,
    content_json: String,
    word_count: i64,
    state: State<'_, AppState>,
) -> Result<String, String> {
    let document_id = {
        let guard = state.active_document_id.lock().map_err(|e| e.to_string())?;
        guard.clone().ok_or("No active document")?
    };

    let db = state.db.lock().map_err(|e| e.to_string())?;
    let now = chrono::Utc::now().to_rfc3339();
    let content_hash = hashing::sha256_hex(content_json.as_bytes());

    if let Some(t) = title {
        db.execute(
            "UPDATE documents SET title = ?1, content_json = ?2, content_hash = ?3, word_count = ?4, updated_at = ?5 WHERE id = ?6",
            params![t, content_json, content_hash, word_count, now, document_id],
        ).map_err(|e| e.to_string())?;
    } else {
        db.execute(
            "UPDATE documents SET content_json = ?1, content_hash = ?2, word_count = ?3, updated_at = ?4 WHERE id = ?5",
            params![content_json, content_hash, word_count, now, document_id],
        ).map_err(|e| e.to_string())?;
    }

    Ok(document_id)
}

#[tauri::command]
pub fn load_document(document_id: String, state: State<'_, AppState>) -> Result<Document, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;

    let doc = db
        .query_row(
            "SELECT id, title, content_json, content_hash, word_count, created_at, updated_at FROM documents WHERE id = ?1",
            params![document_id],
            |row| {
                Ok(Document {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content_json: row.get(2)?,
                    content_hash: row.get(3)?,
                    word_count: row.get(4)?,
                    created_at: row.get(5)?,
                    updated_at: row.get(6)?,
                })
            },
        )
        .map_err(|e| e.to_string())?;

    Ok(doc)
}

#[tauri::command]
pub fn list_documents(state: State<'_, AppState>) -> Result<Vec<DocumentListItem>, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;

    let mut stmt = db
        .prepare("SELECT id, title, word_count, updated_at FROM documents ORDER BY updated_at DESC")
        .map_err(|e| e.to_string())?;

    let rows = stmt
        .query_map([], |row| {
            Ok(DocumentListItem {
                id: row.get(0)?,
                title: row.get(1)?,
                word_count: row.get(2)?,
                updated_at: row.get(3)?,
            })
        })
        .map_err(|e| e.to_string())?;

    let docs: Vec<DocumentListItem> = rows.filter_map(|r| r.ok()).collect();
    Ok(docs)
}
