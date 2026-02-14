use serde::{Deserialize, Serialize};

use super::tier1::Tier1Features;
use super::tier2::Tier2Features;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureVector {
    pub version: String,
    pub window_start_ms: f64,
    pub window_end_ms: f64,
    pub keystroke_count: u32,
    pub tier1: Tier1Features,
    pub tier2: Tier2Features,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DigraphStats {
    pub count: u32,
    pub mean: f64,
    pub std_dev: f64,
    pub median: f64,
    pub p10: f64,
    pub p90: f64,
}

impl DigraphStats {
    pub fn from_samples(samples: &mut Vec<f64>) -> Option<Self> {
        if samples.len() < 5 {
            return None;
        }
        samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        let n = samples.len() as f64;
        let mean = samples.iter().sum::<f64>() / n;
        let variance = samples.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / (n - 1.0);
        let std_dev = variance.sqrt();
        let median = samples[samples.len() / 2];
        let p10 = samples[(samples.len() as f64 * 0.1) as usize];
        let p90 = samples[(samples.len() as f64 * 0.9).min(samples.len() as f64 - 1.0) as usize];

        Some(DigraphStats {
            count: samples.len() as u32,
            mean,
            std_dev,
            median,
            p10,
            p90,
        })
    }
}
