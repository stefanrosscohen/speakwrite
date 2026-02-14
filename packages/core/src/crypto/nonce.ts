/** Generate a random 256-bit nonce. */
export function randomNonce(): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(32));
}
