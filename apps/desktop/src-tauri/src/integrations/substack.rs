use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstackConfig {
    pub subdomain: String,
    pub auth_cookie: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SubstackExport {
    pub html: String,
    pub title: String,
    pub subtitle: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SubstackPublishResult {
    pub draft_id: String,
    pub url: String,
}

/// Convert TipTap JSON content to Substack-compatible HTML.
/// Substack uses standard HTML with some constraints (no custom CSS, no scripts).
pub fn tiptap_to_html(content_json: &str, proof_footer: Option<&str>) -> String {
    let mut html = String::new();

    let doc: Value = match serde_json::from_str(content_json) {
        Ok(v) => v,
        Err(_) => return html,
    };

    let content = match doc.get("content").and_then(|c| c.as_array()) {
        Some(arr) => arr,
        None => return html,
    };

    for node in content {
        let node_type = node.get("type").and_then(|t| t.as_str()).unwrap_or("");

        match node_type {
            "paragraph" => {
                html.push_str("<p>");
                html.push_str(&render_inline(node));
                html.push_str("</p>\n");
            }
            "heading" => {
                let level = node
                    .get("attrs")
                    .and_then(|a| a.get("level"))
                    .and_then(|l| l.as_u64())
                    .unwrap_or(2);

                html.push_str(&format!("<h{}>", level));
                html.push_str(&render_inline(node));
                html.push_str(&format!("</h{}>\n", level));
            }
            "bulletList" => {
                html.push_str("<ul>\n");
                if let Some(items) = node.get("content").and_then(|c| c.as_array()) {
                    for item in items {
                        html.push_str("<li>");
                        html.push_str(&render_list_item(item));
                        html.push_str("</li>\n");
                    }
                }
                html.push_str("</ul>\n");
            }
            "orderedList" => {
                html.push_str("<ol>\n");
                if let Some(items) = node.get("content").and_then(|c| c.as_array()) {
                    for item in items {
                        html.push_str("<li>");
                        html.push_str(&render_list_item(item));
                        html.push_str("</li>\n");
                    }
                }
                html.push_str("</ol>\n");
            }
            "codeBlock" => {
                let text = node
                    .get("content")
                    .and_then(|c| c.as_array())
                    .and_then(|arr| arr.first())
                    .and_then(|n| n.get("text"))
                    .and_then(|t| t.as_str())
                    .unwrap_or("");

                html.push_str("<pre><code>");
                html.push_str(&html_escape(text));
                html.push_str("</code></pre>\n");
            }
            "blockquote" => {
                html.push_str("<blockquote>");
                if let Some(children) = node.get("content").and_then(|c| c.as_array()) {
                    for child in children {
                        if child.get("type").and_then(|t| t.as_str()) == Some("paragraph") {
                            html.push_str("<p>");
                            html.push_str(&render_inline(child));
                            html.push_str("</p>");
                        }
                    }
                }
                html.push_str("</blockquote>\n");
            }
            "horizontalRule" => {
                html.push_str("<hr />\n");
            }
            _ => {}
        }
    }

    // Append proof footer if provided
    if let Some(footer) = proof_footer {
        html.push_str("<hr />\n");
        html.push_str(&format!(
            "<p><em>{}</em></p>\n",
            html_escape(footer)
        ));
    }

    html
}

fn render_inline(node: &Value) -> String {
    let mut result = String::new();

    if let Some(content) = node.get("content").and_then(|c| c.as_array()) {
        for child in content {
            if child.get("type").and_then(|t| t.as_str()) == Some("text") {
                let text = child.get("text").and_then(|t| t.as_str()).unwrap_or("");
                let escaped = html_escape(text);

                let mut output = escaped;

                if let Some(marks) = child.get("marks").and_then(|m| m.as_array()) {
                    for mark in marks {
                        match mark.get("type").and_then(|t| t.as_str()).unwrap_or("") {
                            "bold" => output = format!("<strong>{}</strong>", output),
                            "italic" => output = format!("<em>{}</em>", output),
                            "strike" => output = format!("<s>{}</s>", output),
                            "code" => output = format!("<code>{}</code>", output),
                            "underline" => output = format!("<u>{}</u>", output),
                            "link" => {
                                let href = mark
                                    .get("attrs")
                                    .and_then(|a| a.get("href"))
                                    .and_then(|h| h.as_str())
                                    .unwrap_or("#");
                                output = format!("<a href=\"{}\">{}</a>", html_escape(href), output);
                            }
                            _ => {}
                        }
                    }
                }

                result.push_str(&output);
            }
        }
    }

    result
}

fn render_list_item(item: &Value) -> String {
    if let Some(content) = item.get("content").and_then(|c| c.as_array()) {
        for child in content {
            if child.get("type").and_then(|t| t.as_str()) == Some("paragraph") {
                return render_inline(child);
            }
        }
    }
    String::new()
}

fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

/// Export document as Substack-ready HTML with proof footer.
pub fn export_for_substack(
    title: &str,
    content_json: &str,
    _document_id: &str,
    commitment_count: i64,
    latest_hash: &str,
    keystroke_count: i64,
) -> SubstackExport {
    let proof_footer = format!(
        "Written with Speakwrite | {} commitments | {} keystrokes verified | Proof: {}",
        commitment_count,
        keystroke_count,
        &latest_hash[..16.min(latest_hash.len())]
    );

    let html = tiptap_to_html(content_json, Some(&proof_footer));

    SubstackExport {
        html,
        title: title.to_string(),
        subtitle: None,
    }
}

/// Publish a draft to Substack via their internal API.
/// Requires authentication via session cookie.
pub async fn publish_draft_to_substack(
    config: &SubstackConfig,
    title: &str,
    html_body: &str,
    subtitle: Option<&str>,
) -> Result<SubstackPublishResult, String> {
    let auth_cookie = config
        .auth_cookie
        .as_ref()
        .ok_or("Substack auth cookie not configured. Export to HTML instead.")?;

    let client = reqwest::Client::new();

    let payload = serde_json::json!({
        "draft_title": title,
        "draft_subtitle": subtitle.unwrap_or(""),
        "draft_body": html_body,
        "type": "newsletter",
    });

    let response = client
        .post(format!(
            "https://{}.substack.com/api/v1/drafts",
            config.subdomain
        ))
        .header("Cookie", format!("substack.sid={}", auth_cookie))
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await
        .map_err(|e| format!("Substack API request failed: {}", e))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("Substack API error {}: {}", status, body));
    }

    let result: Value = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse Substack response: {}", e))?;

    let draft_id = result
        .get("id")
        .and_then(|v| v.as_i64())
        .map(|v| v.to_string())
        .unwrap_or_default();

    let url = format!(
        "https://{}.substack.com/publish/post/{}",
        config.subdomain, draft_id
    );

    Ok(SubstackPublishResult { draft_id, url })
}
