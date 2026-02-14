use rusqlite::params;
use serde::{Deserialize, Serialize};
use tauri::State;

use crate::crypto::hashing;
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
    pub content_binding_hash: String,
    pub content_hash: String,
}

#[derive(Deserialize)]
pub struct SubstackPublishArgs {
    subdomain: String,
    auth_cookie: String,
}

#[derive(Serialize)]
pub struct VerifyResult {
    pub valid: bool,
    pub content_hash_matches: bool,
    pub chain_length: i64,
    pub binding_hash: Option<String>,
    pub expected_content_hash: Option<String>,
    pub actual_content_hash: String,
    pub message: String,
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

/// Create a content-binding commitment that seals the commitment chain to the document content.
/// Returns (binding_hash, content_hash, new_sequence_num).
fn create_content_binding(
    db: &rusqlite::Connection,
    document_id: &str,
    content_json: &str,
) -> Result<(String, String, i64), String> {
    let content_hash = hashing::sha256_hex(content_json.as_bytes());

    // Get the current chain tip (latest behavioral commitment)
    let chain_tip: String = db
        .query_row(
            "SELECT commitment_hash FROM commitment_chain WHERE document_id = ?1 ORDER BY sequence_num DESC LIMIT 1",
            params![document_id],
            |row| row.get(0),
        )
        .map_err(|_| "No commitments in chain. Write something and checkpoint first.".to_string())?;

    // Compute the binding: SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)
    let binding_hash = hashing::content_binding_hash(&chain_tip, &content_hash);

    // Get next sequence number
    let sequence: i64 = db
        .query_row(
            "SELECT COALESCE(MAX(sequence_num), -1) + 1 FROM commitment_chain WHERE document_id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .map_err(|e| e.to_string())?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    // Insert the content-binding commitment into the chain
    db.execute(
        "INSERT INTO commitment_chain (document_id, sequence_num, commitment_hash, previous_hash, nonce, timestamp_ms, commitment_type, content_hash)
         VALUES (?1, ?2, ?3, ?4, 'CONTENT_BINDING', ?5, 'content_binding', ?6)",
        params![document_id, sequence, binding_hash, chain_tip, now_ms, content_hash],
    ).map_err(|e| e.to_string())?;

    Ok((binding_hash, content_hash, sequence))
}

#[tauri::command]
pub async fn publish_to_notion(
    args: NotionPublishArgs,
    state: State<'_, AppState>,
) -> Result<PublishResult, String> {
    let (document_id, title, content_json, binding_hash, content_hash) = {
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

        // Create content-binding commitment before publishing
        let (binding_hash, content_hash, _seq) =
            create_content_binding(&db, &doc_id, &content_json)?;

        (doc_id, title, content_json, binding_hash, content_hash)
    };

    let (commitment_count, _latest_hash, keystroke_count) = {
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
        &binding_hash,
        keystroke_count,
    )
    .await?;

    Ok(PublishResult {
        url: result.url,
        platform: "notion".to_string(),
        content_binding_hash: binding_hash,
        content_hash,
    })
}

#[tauri::command]
pub async fn publish_to_substack(
    args: SubstackPublishArgs,
    state: State<'_, AppState>,
) -> Result<PublishResult, String> {
    let (document_id, title, content_json, binding_hash, content_hash) = {
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

        // Create content-binding commitment before publishing
        let (binding_hash, content_hash, _seq) =
            create_content_binding(&db, &doc_id, &content_json)?;

        (doc_id, title, content_json, binding_hash, content_hash)
    };

    let (commitment_count, _latest_hash, keystroke_count) = {
        let db = state.db.lock().map_err(|e| e.to_string())?;
        get_proof_meta(&db, &document_id)
    };

    let export = substack::export_for_substack(
        &title,
        &content_json,
        &document_id,
        commitment_count,
        &binding_hash,
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
        content_binding_hash: binding_hash,
        content_hash,
    })
}

/// Export document as HTML with proof footer (for manual Substack paste).
/// Also creates a content-binding commitment.
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

    // Create content-binding commitment
    let (binding_hash, _content_hash, _seq) =
        create_content_binding(&db, &document_id, &content_json)?;

    let (commitment_count, _latest, keystroke_count) = get_proof_meta(&db, &document_id);

    let proof_footer = format!(
        "Written with Speakwrite | {} commitments | {} keystrokes | Binding: {}",
        commitment_count,
        keystroke_count,
        &binding_hash[..16.min(binding_hash.len())]
    );

    Ok(substack::tiptap_to_html(&content_json, Some(&proof_footer)))
}

/// Verify that a document's content matches its content-binding commitment.
/// This is the core verification function: given content, does the proof chain cover it?
#[tauri::command]
pub fn verify_content_binding(
    content: String,
    state: State<'_, AppState>,
) -> Result<VerifyResult, String> {
    let document_id = state
        .active_document_id
        .lock()
        .map_err(|e| e.to_string())?
        .clone()
        .ok_or("No active document")?;

    let db = state.db.lock().map_err(|e| e.to_string())?;

    let actual_content_hash = hashing::sha256_hex(content.as_bytes());

    // Find the content-binding commitment
    let binding_row: Result<(String, String, Option<String>), _> = db.query_row(
        "SELECT commitment_hash, previous_hash, content_hash FROM commitment_chain
         WHERE document_id = ?1 AND commitment_type = 'content_binding'
         ORDER BY sequence_num DESC LIMIT 1",
        params![document_id],
        |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
    );

    let chain_length: i64 = db
        .query_row(
            "SELECT COUNT(*) FROM commitment_chain WHERE document_id = ?1",
            params![document_id],
            |row| row.get(0),
        )
        .unwrap_or(0);

    match binding_row {
        Ok((binding_hash, chain_tip, stored_content_hash)) => {
            let stored_hash = stored_content_hash.unwrap_or_default();
            let content_matches = actual_content_hash == stored_hash;

            // Re-derive the binding to verify it's correct
            let expected_binding = hashing::content_binding_hash(&chain_tip, &stored_hash);
            let binding_valid = expected_binding == binding_hash;

            let valid = content_matches && binding_valid;

            let message = if valid {
                "Content verified: this text was produced by the proven keystroke chain.".to_string()
            } else if !content_matches {
                "Content modified: the text does not match the content bound at publish time.".to_string()
            } else {
                "Binding invalid: the content-binding commitment could not be re-derived.".to_string()
            };

            Ok(VerifyResult {
                valid,
                content_hash_matches: content_matches,
                chain_length,
                binding_hash: Some(binding_hash),
                expected_content_hash: Some(stored_hash),
                actual_content_hash,
                message,
            })
        }
        Err(_) => Ok(VerifyResult {
            valid: false,
            content_hash_matches: false,
            chain_length,
            binding_hash: None,
            expected_content_hash: None,
            actual_content_hash,
            message: "No content-binding commitment found. Document has not been published yet."
                .to_string(),
        }),
    }
}
