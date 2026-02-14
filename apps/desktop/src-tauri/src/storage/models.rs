use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    pub id: String,
    pub title: String,
    pub content_json: Option<String>,
    pub content_hash: Option<String>,
    pub word_count: i64,
    pub created_at: String,
    pub updated_at: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub id: String,
    pub document_id: String,
    pub started_at: String,
    pub ended_at: Option<String>,
    pub keystroke_count: i64,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommitmentEntry {
    pub sequence_num: i64,
    pub commitment_hash: String,
    pub previous_hash: Option<String>,
    pub timestamp_ms: i64,
}
