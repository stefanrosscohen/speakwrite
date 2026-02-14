use sha2::{Sha256, Digest};

/// Compute SHA-256 hash, return as hex string.
pub fn sha256_hex(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    let result = hasher.finalize();
    hex_encode(&result)
}

/// Compute incremental commitment: SHA-256(previous || nonce || data)
pub fn commitment_hash(previous: Option<&str>, nonce: &[u8], data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    if let Some(prev) = previous {
        hasher.update(hex_decode(prev));
    }
    hasher.update(nonce);
    hasher.update(data);
    let result = hasher.finalize();
    hex_encode(&result)
}

/// Generate a random 256-bit nonce.
pub fn random_nonce() -> [u8; 32] {
    let mut nonce = [0u8; 32];
    getrandom(&mut nonce);
    nonce
}

fn getrandom(buf: &mut [u8]) {
    use rand::RngCore;
    rand::thread_rng().fill_bytes(buf);
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn hex_decode(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap_or(0))
        .collect()
}
