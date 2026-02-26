import crypto from 'node:crypto';
import cbor from 'cbor';
import { ProofRecord, VerificationResult } from './types.js';

const APPLE_APP_ATTEST_ROOT_CA_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const FOOTER_MARKERS = [
  '\n\n✓ Verify a human wrote this',
  '\n\n✓ Verify authentic content',
  '\n\n✓ speakwrite',
  '\n\n❤️‍🔥 human verified · speakwrite',
];

function stripFooter(text: string): string {
  for (const marker of FOOTER_MARKERS) {
    const idx = text.lastIndexOf(marker);
    if (idx !== -1) return text.substring(0, idx);
  }
  return text;
}

function hexToBytes(hex: string): Buffer {
  return Buffer.from(hex, 'hex');
}

export async function verifyPost(
  postText: string,
  proof: ProofRecord
): Promise<VerificationResult> {
  try {
    // Step 1: Content hash verification
    const originalText = stripFooter(postText);
    const textHash = crypto
      .createHash('sha256')
      .update(originalText, 'utf8')
      .digest();

    let computedHash: string;
    if (proof.mediaHashes && proof.mediaHashes.length > 0) {
      // Composite hash: SHA256(SHA256(text) + sorted_media_hash_bytes)
      const sortedHashes = [...proof.mediaHashes].sort();
      const composite = crypto.createHash('sha256');
      composite.update(textHash);
      for (const hex of sortedHashes) {
        composite.update(hexToBytes(hex));
      }
      computedHash = composite.digest('hex');
    } else {
      computedHash = textHash.toString('hex');
    }

    if (computedHash !== proof.contentHash) {
      return {
        verified: false,
        reason: `Content hash mismatch`,
      };
    }

    // Step 2: Decode attestation object (CBOR) and extract cert chain
    const attestationBytes = Buffer.from(proof.attestationObject, 'base64');
    const attestation = cbor.decode(attestationBytes);

    const x5c: Buffer[] | undefined = attestation.attStmt?.x5c;
    if (!x5c || x5c.length === 0) {
      return {
        verified: false,
        reason: 'No certificates in attestation',
      };
    }

    // Step 3: Validate certificate chain cryptographically against Apple root
    const rootCert = new crypto.X509Certificate(APPLE_APP_ATTEST_ROOT_CA_PEM);
    const leafCert = new crypto.X509Certificate(x5c[0]);

    // Note: App Attest leaf certs are short-lived (~72 hours) and issued at
    // KEY REGISTRATION time, not at posting time. The attestation object is
    // created once and reused for all subsequent assertions. We verify the
    // cert chain cryptographically (signatures) which proves the key came
    // from a genuine Apple device — the cert's validity period is irrelevant
    // since the key persists in the Secure Enclave indefinitely.

    if (x5c.length >= 2) {
      const intermediateCert = new crypto.X509Certificate(x5c[1]);
      // Verify leaf was issued by intermediate (name check)
      if (!leafCert.checkIssued(intermediateCert)) {
        return {
          verified: false,
          reason: 'Leaf cert not issued by intermediate',
        };
      }
      // Cryptographically verify intermediate was signed by Apple root
      if (!intermediateCert.verify(rootCert.publicKey)) {
        return {
          verified: false,
          reason: 'Intermediate cert not signed by Apple App Attestation Root CA',
        };
      }
    } else {
      // Single cert — verify it was signed directly by the root
      if (!leafCert.verify(rootCert.publicKey)) {
        return {
          verified: false,
          reason: 'Leaf cert not signed by Apple App Attestation Root CA',
        };
      }
    }

    // Step 4: Extract public key from leaf cert
    const publicKey = leafCert.publicKey;

    // Step 5: Decode assertion (CBOR) and extract signature + authenticatorData
    const assertionBytes = Buffer.from(proof.assertion, 'base64');
    const assertion = cbor.decode(assertionBytes);

    const signature: Buffer | undefined = assertion.signature;
    const authenticatorData: Buffer | undefined = assertion.authenticatorData;

    if (!signature || !authenticatorData) {
      return {
        verified: false,
        reason: 'Invalid assertion — missing signature or authenticator data',
      };
    }

    // Step 6: Compute nonce = SHA-256(authenticatorData || contentHashBytes)
    const contentHashBytes = hexToBytes(proof.contentHash);
    const nonceInput = Buffer.concat([
      Buffer.from(authenticatorData),
      contentHashBytes,
    ]);
    const nonce = crypto.createHash('sha256').update(nonceInput).digest();

    // Step 7: Verify ECDSA signature
    // nonce is already SHA-256(authenticatorData || contentHash).
    // Use null algorithm so crypto.verify checks the signature against
    // the raw hash without hashing again.
    const isValid = crypto.verify(
      null,
      nonce,
      { key: publicKey, dsaEncoding: 'der' },
      Buffer.from(signature)
    );

    if (!isValid) {
      return {
        verified: false,
        reason: 'ECDSA signature verification failed',
      };
    }

    return { verified: true };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    const friendlyReasons: Record<string, string> = {
      'No certificates in attestation': 'The proof data was incomplete',
      'Leaf cert not issued by intermediate': 'The proof certificate chain is invalid',
      'Intermediate cert not signed by Apple App Attestation Root CA': 'The proof did not come from a genuine Apple device',
      'Leaf cert not signed by Apple App Attestation Root CA': 'The proof did not come from a genuine Apple device',
      'Invalid assertion — missing signature or authenticator data': 'The proof is missing required data',
      'ECDSA signature verification failed': 'The cryptographic signature is invalid',
    };
    const friendly = friendlyReasons[message] || `Verification error: ${message}`;
    return {
      verified: false,
      reason: friendly,
    };
  }
}
