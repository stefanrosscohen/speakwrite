/**
 * Cryptographic hashing utilities for commitment chains.
 * Uses Web Crypto API — all functions are async.
 * Byte layout matches the Rust implementation exactly.
 */

export function hexEncode(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function hexDecode(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

function concatBytes(...arrays: Uint8Array[]): Uint8Array {
  const totalLength = arrays.reduce((sum, arr) => sum + arr.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const arr of arrays) {
    result.set(arr, offset);
    offset += arr.length;
  }
  return result;
}

async function sha256(data: Uint8Array): Promise<ArrayBuffer> {
  // Copy into a fresh ArrayBuffer to satisfy TS 5.9 BufferSource constraints
  const buf = new ArrayBuffer(data.length);
  new Uint8Array(buf).set(data);
  return crypto.subtle.digest("SHA-256", buf);
}

/** Compute SHA-256 hash, return as hex string. */
export async function sha256Hex(
  data: string | Uint8Array,
): Promise<string> {
  const encoded =
    typeof data === "string" ? new TextEncoder().encode(data) : data;
  const hashBuffer = await sha256(encoded);
  return hexEncode(new Uint8Array(hashBuffer));
}

/** Compute incremental commitment: SHA-256(previous || nonce || data || documentHash?) */
export async function commitmentHash(
  previous: string | null,
  nonce: Uint8Array,
  data: Uint8Array,
  documentHash?: string,
): Promise<string> {
  const parts: Uint8Array[] = [];
  if (previous) {
    parts.push(hexDecode(previous));
  }
  parts.push(nonce);
  parts.push(data);
  if (documentHash) {
    parts.push(hexDecode(documentHash));
  }
  const combined = concatBytes(...parts);
  const hashBuffer = await sha256(combined);
  return hexEncode(new Uint8Array(hashBuffer));
}

/**
 * Compute content-binding commitment: SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)
 * Binds the entire commitment chain to the final document content.
 */
export async function contentBindingHash(
  chainTip: string,
  contentHash: string,
): Promise<string> {
  const combined = concatBytes(
    hexDecode(chainTip),
    new TextEncoder().encode("CONTENT_BINDING"),
    hexDecode(contentHash),
  );
  const hashBuffer = await sha256(combined);
  return hexEncode(new Uint8Array(hashBuffer));
}
