import { describe, it, expect } from "vitest";
import {
  sha256Hex,
  commitmentHash,
  contentBindingHash,
  hexEncode,
  hexDecode,
} from "../../src/crypto/hashing";
import { randomNonce } from "../../src/crypto/nonce";

describe("hexEncode / hexDecode", () => {
  it("round-trips correctly", () => {
    const bytes = new Uint8Array([0, 1, 127, 128, 255]);
    const hex = hexEncode(bytes);
    expect(hex).toBe("00017f80ff");
    expect(hexDecode(hex)).toEqual(bytes);
  });

  it("handles empty input", () => {
    expect(hexEncode(new Uint8Array([]))).toBe("");
    expect(hexDecode("")).toEqual(new Uint8Array([]));
  });
});

describe("sha256Hex", () => {
  it("hashes empty string correctly", async () => {
    // Known SHA-256 of empty string
    const hash = await sha256Hex("");
    expect(hash).toBe(
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    );
  });

  it("hashes 'abc' correctly", async () => {
    const hash = await sha256Hex("abc");
    expect(hash).toBe(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });

  it("accepts Uint8Array input", async () => {
    const hash = await sha256Hex(new TextEncoder().encode("abc"));
    expect(hash).toBe(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });

  it("produces different hashes for different inputs", async () => {
    const h1 = await sha256Hex("hello");
    const h2 = await sha256Hex("world");
    expect(h1).not.toBe(h2);
  });
});

describe("commitmentHash", () => {
  it("produces deterministic output", async () => {
    const nonce = new Uint8Array(32).fill(42);
    const data = new TextEncoder().encode("test data");

    const h1 = await commitmentHash(null, nonce, data);
    const h2 = await commitmentHash(null, nonce, data);
    expect(h1).toBe(h2);
  });

  it("differs with null vs non-null previous", async () => {
    const nonce = new Uint8Array(32).fill(1);
    const data = new TextEncoder().encode("data");
    const previous = await sha256Hex("previous");

    const h1 = await commitmentHash(null, nonce, data);
    const h2 = await commitmentHash(previous, nonce, data);
    expect(h1).not.toBe(h2);
  });

  it("differs with different nonces", async () => {
    const data = new TextEncoder().encode("data");
    const nonce1 = new Uint8Array(32).fill(1);
    const nonce2 = new Uint8Array(32).fill(2);

    const h1 = await commitmentHash(null, nonce1, data);
    const h2 = await commitmentHash(null, nonce2, data);
    expect(h1).not.toBe(h2);
  });
});

describe("contentBindingHash", () => {
  it("produces deterministic output", async () => {
    const chainTip = await sha256Hex("chain tip");
    const contentHash = await sha256Hex("document content");

    const h1 = await contentBindingHash(chainTip, contentHash);
    const h2 = await contentBindingHash(chainTip, contentHash);
    expect(h1).toBe(h2);
  });

  it("differs with different chain tips", async () => {
    const contentHash = await sha256Hex("content");
    const tip1 = await sha256Hex("tip1");
    const tip2 = await sha256Hex("tip2");

    const h1 = await contentBindingHash(tip1, contentHash);
    const h2 = await contentBindingHash(tip2, contentHash);
    expect(h1).not.toBe(h2);
  });
});

describe("randomNonce", () => {
  it("produces 32 bytes", () => {
    const nonce = randomNonce();
    expect(nonce.length).toBe(32);
  });

  it("produces different values on each call", () => {
    const n1 = randomNonce();
    const n2 = randomNonce();
    expect(hexEncode(n1)).not.toBe(hexEncode(n2));
  });
});
