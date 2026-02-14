import { invoke } from "@tauri-apps/api/core";
import type {
  KeystrokeEvent,
  StartSessionResult,
  CheckpointResult,
  ProofStatus,
  DocumentInfo,
  DocumentListItem,
  PublishResult,
  VerifyResult,
} from "./types";

export async function recordKeystrokeBatch(events: KeystrokeEvent[]): Promise<void> {
  return invoke("record_keystroke_batch", { events });
}

export async function startSession(documentId?: string): Promise<StartSessionResult> {
  return invoke("start_session", { documentId: documentId ?? null });
}

export async function endSession(): Promise<void> {
  return invoke("end_session");
}

export async function checkpointSession(): Promise<CheckpointResult> {
  return invoke("checkpoint_session");
}

export async function getProofStatus(): Promise<ProofStatus> {
  return invoke("get_proof_status");
}

export async function saveDocument(
  contentJson: string,
  wordCount: number,
  title?: string,
): Promise<string> {
  return invoke("save_document", {
    title: title ?? null,
    contentJson,
    wordCount,
  });
}

export async function loadDocument(documentId: string): Promise<DocumentInfo> {
  return invoke("load_document", { documentId });
}

export async function listDocuments(): Promise<DocumentListItem[]> {
  return invoke("list_documents");
}

export async function publishToNotion(
  apiKey: string,
  parentPageId: string,
): Promise<PublishResult> {
  return invoke("publish_to_notion", {
    args: { api_key: apiKey, parent_page_id: parentPageId },
  });
}

export async function publishToSubstack(
  subdomain: string,
  authCookie: string,
): Promise<PublishResult> {
  return invoke("publish_to_substack", {
    args: { subdomain, auth_cookie: authCookie },
  });
}

export async function exportHtml(): Promise<string> {
  return invoke("export_html");
}

export async function verifyContentBinding(content: string): Promise<VerifyResult> {
  return invoke("verify_content_binding", { content });
}
