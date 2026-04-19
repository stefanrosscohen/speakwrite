import { Request, Response } from 'express';

// Node 18+ has globalThis.fetch; alias to avoid shadowing express Response.
const httpFetch: typeof globalThis.fetch = globalThis.fetch;

// In-memory store: DID → { nullifierHash, verifiedAt }
// Keyed by nullifier_hash to deduplicate the same World ID across DIDs.
const verifiedDIDs = new Map<string, { nullifierHash: string; verifiedAt: string }>();
const usedNullifiers = new Set<string>();

const WORLDID_ACTION = 'verify-speakwrite-user';
const WORLDID_VERIFY_URL = 'https://developer.worldcoin.org/api/v2/verify';

interface WorldIDProofBody {
  did: string;
  nullifier_hash: string;
  merkle_root: string;
  proof: string;
  verification_level: string;
  signal_hash?: string;
}

function isValidWorldIDBody(body: unknown): body is WorldIDProofBody {
  if (!body || typeof body !== 'object') return false;
  const b = body as Record<string, unknown>;
  return (
    typeof b.did === 'string' && b.did.length > 0 &&
    typeof b.nullifier_hash === 'string' && b.nullifier_hash.startsWith('0x') &&
    typeof b.merkle_root === 'string' && b.merkle_root.startsWith('0x') &&
    typeof b.proof === 'string' && b.proof.startsWith('0x') &&
    typeof b.verification_level === 'string'
  );
}

/**
 * POST /api/worldid/verify
 *
 * Accepts a World ID proof from a Speakwrite user, verifies it against
 * the World ID Cloud Verify API, and records the verified DID.
 *
 * Required env: WORLDID_APP_ID
 */
export async function handleWorldIDVerify(req: Request, res: Response): Promise<void> {
  const appId = process.env.WORLDID_APP_ID;
  if (!appId) {
    res.status(503).json({ error: 'World ID not configured on this server' });
    return;
  }

  if (!isValidWorldIDBody(req.body)) {
    res.status(400).json({ error: 'Missing or invalid fields: did, nullifier_hash, merkle_root, proof, verification_level' });
    return;
  }

  const { did, nullifier_hash, merkle_root, proof, verification_level, signal_hash } = req.body;

  // Prevent the same World ID (nullifier) being used for multiple accounts.
  if (usedNullifiers.has(nullifier_hash)) {
    const existing = [...verifiedDIDs.entries()].find(([, v]) => v.nullifierHash === nullifier_hash);
    if (existing && existing[0] !== did) {
      res.status(409).json({ error: 'This World ID is already linked to another account' });
      return;
    }
  }

  // Call the World ID Cloud Verify API.
  let worldRes: globalThis.Response;
  try {
    worldRes = await httpFetch(`${WORLDID_VERIFY_URL}/${appId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nullifier_hash,
        merkle_root,
        proof,
        verification_level,
        action: WORLDID_ACTION,
        ...(signal_hash ? { signal_hash } : {}),
      }),
    });
  } catch (err) {
    console.error('World ID API network error:', err);
    res.status(502).json({ error: 'Could not reach World ID verification service' });
    return;
  }

  if (!worldRes.ok) {
    const body = await worldRes.json().catch(() => ({}));
    const detail = (body as Record<string, string>).detail ?? 'Verification failed';
    console.warn(`World ID rejected proof for ${did}: ${detail}`);
    res.status(400).json({ error: detail });
    return;
  }

  // Success — record the verified DID.
  const verifiedAt = new Date().toISOString();
  verifiedDIDs.set(did, { nullifierHash: nullifier_hash, verifiedAt });
  usedNullifiers.add(nullifier_hash);

  console.log(`World ID verified: ${did} (nullifier: ${nullifier_hash.slice(0, 10)}...)`);
  res.json({ verified: true, verifiedAt });
}

/**
 * GET /api/worldid/status/:did
 *
 * Returns whether a given AT Protocol DID has completed World ID verification.
 */
export async function handleWorldIDStatus(req: Request, res: Response): Promise<void> {
  const { did } = req.params;

  if (!did || typeof did !== 'string') {
    res.status(400).json({ error: 'Missing did parameter' });
    return;
  }

  const record = verifiedDIDs.get(did);
  if (record) {
    res.json({ verified: true, verifiedAt: record.verifiedAt });
  } else {
    res.json({ verified: false });
  }
}
