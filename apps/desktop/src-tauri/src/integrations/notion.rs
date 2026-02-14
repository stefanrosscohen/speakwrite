use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

const NOTION_API_VERSION: &str = "2022-06-28";
const NOTION_API_BASE: &str = "https://api.notion.com/v1";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotionConfig {
    pub api_key: String,
    pub parent_page_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct PublishResult {
    pub page_id: String,
    pub url: String,
}

/// Convert TipTap JSON content to Notion blocks.
/// Handles paragraphs, headings, bullet lists, and code blocks.
fn tiptap_to_notion_blocks(content_json: &str) -> Vec<Value> {
    let mut blocks = Vec::new();

    let doc: Value = match serde_json::from_str(content_json) {
        Ok(v) => v,
        Err(_) => return blocks,
    };

    let content = match doc.get("content").and_then(|c| c.as_array()) {
        Some(arr) => arr,
        None => return blocks,
    };

    for node in content {
        let node_type = node.get("type").and_then(|t| t.as_str()).unwrap_or("");

        match node_type {
            "paragraph" => {
                let rich_text = extract_rich_text(node);
                blocks.push(json!({
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": rich_text
                    }
                }));
            }
            "heading" => {
                let level = node
                    .get("attrs")
                    .and_then(|a| a.get("level"))
                    .and_then(|l| l.as_u64())
                    .unwrap_or(1);

                let rich_text = extract_rich_text(node);
                let heading_type = match level {
                    1 => "heading_1",
                    2 => "heading_2",
                    _ => "heading_3",
                };

                blocks.push(json!({
                    "object": "block",
                    "type": heading_type,
                    heading_type: {
                        "rich_text": rich_text
                    }
                }));
            }
            "bulletList" => {
                if let Some(items) = node.get("content").and_then(|c| c.as_array()) {
                    for item in items {
                        let rich_text = extract_list_item_text(item);
                        blocks.push(json!({
                            "object": "block",
                            "type": "bulleted_list_item",
                            "bulleted_list_item": {
                                "rich_text": rich_text
                            }
                        }));
                    }
                }
            }
            "orderedList" => {
                if let Some(items) = node.get("content").and_then(|c| c.as_array()) {
                    for item in items {
                        let rich_text = extract_list_item_text(item);
                        blocks.push(json!({
                            "object": "block",
                            "type": "numbered_list_item",
                            "numbered_list_item": {
                                "rich_text": rich_text
                            }
                        }));
                    }
                }
            }
            "codeBlock" => {
                let text = node
                    .get("content")
                    .and_then(|c| c.as_array())
                    .and_then(|arr| arr.first())
                    .and_then(|n| n.get("text"))
                    .and_then(|t| t.as_str())
                    .unwrap_or("");

                blocks.push(json!({
                    "object": "block",
                    "type": "code",
                    "code": {
                        "rich_text": [{ "type": "text", "text": { "content": text } }],
                        "language": "plain text"
                    }
                }));
            }
            "blockquote" => {
                let rich_text = extract_rich_text_deep(node);
                blocks.push(json!({
                    "object": "block",
                    "type": "quote",
                    "quote": {
                        "rich_text": rich_text
                    }
                }));
            }
            "horizontalRule" => {
                blocks.push(json!({
                    "object": "block",
                    "type": "divider",
                    "divider": {}
                }));
            }
            _ => {
                // Fall back to paragraph for unknown types
                let rich_text = extract_rich_text(node);
                if !rich_text.is_empty() {
                    blocks.push(json!({
                        "object": "block",
                        "type": "paragraph",
                        "paragraph": {
                            "rich_text": rich_text
                        }
                    }));
                }
            }
        }
    }

    blocks
}

fn extract_rich_text(node: &Value) -> Vec<Value> {
    let mut result = Vec::new();

    if let Some(content) = node.get("content").and_then(|c| c.as_array()) {
        for child in content {
            if child.get("type").and_then(|t| t.as_str()) == Some("text") {
                let text = child.get("text").and_then(|t| t.as_str()).unwrap_or("");
                let mut annotations = json!({});

                if let Some(marks) = child.get("marks").and_then(|m| m.as_array()) {
                    for mark in marks {
                        match mark.get("type").and_then(|t| t.as_str()).unwrap_or("") {
                            "bold" => annotations["bold"] = json!(true),
                            "italic" => annotations["italic"] = json!(true),
                            "strike" => annotations["strikethrough"] = json!(true),
                            "code" => annotations["code"] = json!(true),
                            "underline" => annotations["underline"] = json!(true),
                            _ => {}
                        }
                    }
                }

                result.push(json!({
                    "type": "text",
                    "text": { "content": text },
                    "annotations": annotations
                }));
            }
        }
    }

    if result.is_empty() {
        result.push(json!({
            "type": "text",
            "text": { "content": "" }
        }));
    }

    result
}

fn extract_rich_text_deep(node: &Value) -> Vec<Value> {
    let mut result = Vec::new();

    if let Some(content) = node.get("content").and_then(|c| c.as_array()) {
        for child in content {
            let child_type = child.get("type").and_then(|t| t.as_str()).unwrap_or("");
            if child_type == "text" {
                let text = child.get("text").and_then(|t| t.as_str()).unwrap_or("");
                result.push(json!({
                    "type": "text",
                    "text": { "content": text }
                }));
            } else if child_type == "paragraph" {
                result.extend(extract_rich_text(child));
            }
        }
    }

    result
}

fn extract_list_item_text(item: &Value) -> Vec<Value> {
    if let Some(content) = item.get("content").and_then(|c| c.as_array()) {
        for child in content {
            if child.get("type").and_then(|t| t.as_str()) == Some("paragraph") {
                return extract_rich_text(child);
            }
        }
    }
    vec![json!({"type": "text", "text": {"content": ""}})]
}

/// Create a Notion callout block with Speakwrite proof metadata.
fn proof_callout_block(
    commitment_count: i64,
    latest_hash: &str,
    keystroke_count: i64,
    document_id: &str,
) -> Value {
    let proof_text = format!(
        "Speakwrite Proof | {} commitments | {} keystrokes | Latest: {}... | Doc: {}",
        commitment_count,
        keystroke_count,
        &latest_hash[..16.min(latest_hash.len())],
        &document_id[..8.min(document_id.len())]
    );

    json!({
        "object": "block",
        "type": "callout",
        "callout": {
            "rich_text": [{
                "type": "text",
                "text": { "content": proof_text }
            }],
            "icon": { "type": "emoji", "emoji": "🔏" },
            "color": "green_background"
        }
    })
}

/// Publish a document to Notion as a new page.
pub async fn publish_to_notion(
    config: &NotionConfig,
    title: &str,
    content_json: &str,
    document_id: &str,
    commitment_count: i64,
    latest_hash: &str,
    keystroke_count: i64,
) -> Result<PublishResult, String> {
    let client = reqwest::Client::new();

    // Build content blocks from TipTap JSON
    let mut children = tiptap_to_notion_blocks(content_json);

    // Add divider and proof callout at the end
    children.push(json!({
        "object": "block",
        "type": "divider",
        "divider": {}
    }));
    children.push(proof_callout_block(
        commitment_count,
        latest_hash,
        keystroke_count,
        document_id,
    ));

    // Build the page creation payload
    let parent = if let Some(ref page_id) = config.parent_page_id {
        json!({ "type": "page_id", "page_id": page_id })
    } else {
        // If no parent, we need a page_id — this will fail if not provided.
        // Users must configure a parent page or database.
        return Err("No parent page configured. Set a Notion parent page ID in settings.".into());
    };

    let payload = json!({
        "parent": parent,
        "properties": {
            "title": {
                "title": [{
                    "text": { "content": title }
                }]
            }
        },
        "children": children
    });

    let response = client
        .post(format!("{}/pages", NOTION_API_BASE))
        .header("Authorization", format!("Bearer {}", config.api_key))
        .header("Notion-Version", NOTION_API_VERSION)
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await
        .map_err(|e| format!("Notion API request failed: {}", e))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("Notion API error {}: {}", status, body));
    }

    let result: Value = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse Notion response: {}", e))?;

    let page_id = result
        .get("id")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    let url = result
        .get("url")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    Ok(PublishResult { page_id, url })
}
