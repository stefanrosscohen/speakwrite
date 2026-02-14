use rusqlite::params;
use serde::{Deserialize, Serialize};
use tauri::State;

use crate::integrations::{notion, substack};
use crate::state::AppState;

#[derive(Deserialize)]
pub struct NotionPublishArgs {
    api_key: String,
    parent_page_id: String,
}

#[derive(Serialize)]
pub struct PublishResult {
    pub url: String,
    pub platform: String,
}

#[derive(Deserialize)]
pub struct SubstackPublishArgs {
    subdomain: String,
    auth_cookie: String,
}

/// Gather proof metadata for the active document.
fn get_proof_meta(
    db: &rusqlite::Connection,
    document_id: &str,
) -> (i64, String, i64) {
    let commitment_count: i64 = db
        .query_row(
            "SELECT COUNT(*) FROM commitment_chain WHERE document_id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .unwrap_or(0);

    let latest_hash: String = db
        .query_row(
            "SELECT commitment_hash FROM commitment_chain WHERE document_id = ?1 ORDER BY sequence_num DESC LIMIT 1",
            params![document_id],
            |row| row.get(0),
        )
        .unwrap_or_else(|_| "none".to_string());

    let keystroke_count: i64 = db
        .query_row(
            "SELECT COALESCE(SUM(keystroke_count), 0) FROM sessions WHERE document_id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .unwrap_or(0);

    (commitment_count, latest_hash, keystroke_count)
}

#[tauri::command]
pub async fn publish_to_notion(
    args: NotionPublishArgs,
    state: State<'_, AppState>,
) -> Result<PublishResult, String> {
    let (document_id, title, content_json) = {
        let doc_id = state
            .active_document_id
            .lock()
            .map_err(|e| e.to_string())?
            .clone()
            .ok_or("No active document")?;

        let db = state.db.lock().map_err(|e| e.to_string())?;

        let (title, content_json): (String, String) = db
            .query_row(
                "SELECT title, COALESCE(content_json, '{}') FROM documents WHERE id = ?1",
                params![doc_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .map_err(|e| e.to_string())?;

        (doc_id, title, content_json)
    };

    let (commitment_count, latest_hash, keystroke_count) = {
        let db = state.db.lock().map_err(|e| e.to_string())?;
        get_proof_meta(&db, &document_id)
    };

    let config = notion::NotionConfig {
        api_key: args.api_key,
        parent_page_id: Some(args.parent_page_id),
    };

    let result = notion::publish_to_notion(
        &config,
        &title,
        &content_json,
        &document_id,
        commitment_count,
        &latest_hash,
        keystroke_count,
    )
    .await?;

    Ok(PublishResult {
        url: result.url,
        platform: "notion".to_string(),
    })
}

#[tauri::command]
pub async fn publish_to_substack(
    args: SubstackPublishArgs,
    state: State<'_, AppState>,
) -> Result<PublishResult, String> {
    let (document_id, title, content_json) = {
        let doc_id = state
            .active_document_id
            .lock()
            .map_err(|e| e.to_string())?
            .clone()
            .ok_or("No active document")?;

        let db = state.db.lock().map_err(|e| e.to_string())?;

        let (title, content_json): (String, String) = db
            .query_row(
                "SELECT title, COALESCE(content_json, '{}') FROM documents WHERE id = ?1",
                params![doc_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .map_err(|e| e.to_string())?;

        (doc_id, title, content_json)
    };

    let (commitment_count, latest_hash, keystroke_count) = {
        let db = state.db.lock().map_err(|e| e.to_string())?;
        get_proof_meta(&db, &document_id)
    };

    let export = substack::export_for_substack(
        &title,
        &content_json,
        &document_id,
        commitment_count,
        &latest_hash,
        keystroke_count,
    );

    let config = substack::SubstackConfig {
        subdomain: args.subdomain,
        auth_cookie: Some(args.auth_cookie),
    };

    let result = substack::publish_draft_to_substack(
        &config,
        &export.title,
        &export.html,
        export.subtitle.as_deref(),
    )
    .await?;

    Ok(PublishResult {
        url: result.url,
        platform: "substack".to_string(),
    })
}

/// Export document as HTML with proof footer (for manual Substack paste).
#[tauri::command]
pub fn export_html(state: State<'_, AppState>) -> Result<String, String> {
    let document_id = state
        .active_document_id
        .lock()
        .map_err(|e| e.to_string())?
        .clone()
        .ok_or("No active document")?;

    let db = state.db.lock().map_err(|e| e.to_string())?;

    let content_json: String = db
        .query_row(
            "SELECT COALESCE(content_json, '{}') FROM documents WHERE id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .map_err(|e| e.to_string())?;

    let (commitment_count, latest_hash, keystroke_count) = get_proof_meta(&db, &document_id);

    let proof_footer = format!(
        "Written with Speakwrite | {} commitments | {} keystrokes verified | Proof: {}",
        commitment_count,
        keystroke_count,
        &latest_hash[..16.min(latest_hash.len())]
    );

    Ok(substack::tiptap_to_html(&content_json, Some(&proof_footer)))
}
