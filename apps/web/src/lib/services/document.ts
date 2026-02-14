import { db } from "../db";
import { sha256Hex } from "@speakwrite/core";
import { getActiveDocumentId } from "./session";

export async function saveDocument(
  contentJson: string,
  wordCount: number,
  title?: string,
): Promise<string> {
  const docId = getActiveDocumentId();
  if (!docId) throw new Error("No active document");

  const contentHash = await sha256Hex(contentJson);

  await db.documents.update(docId, {
    content_json: contentJson,
    content_hash: contentHash,
    word_count: wordCount,
    updated_at: new Date().toISOString(),
    ...(title ? { title } : {}),
  });

  return docId;
}

export async function loadDocument(documentId: string) {
  const doc = await db.documents.get(documentId);
  if (!doc) throw new Error(`Document ${documentId} not found`);
  return doc;
}

export async function listDocuments() {
  return db.documents.orderBy("updated_at").reverse().toArray();
}
