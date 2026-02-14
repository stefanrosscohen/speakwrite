use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::capture::events::KeystrokeEvent;
use super::vector::DigraphStats;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tier1Features {
    pub flight_time_mean: f64,
    pub flight_time_std: f64,
    pub flight_time_median: f64,
    pub hold_time_mean: f64,
    pub hold_time_std: f64,
    pub digraph_count: u32,
    pub digraph_matrix: HashMap<String, DigraphStats>,
    pub overlap_ratio: f64,
    pub typing_speed_cpm: f64,
}

const PAUSE_MAX_MS: f64 = 30_000.0;
const HOLD_MAX_MS: f64 = 1_000.0;

pub fn extract(events: &[KeystrokeEvent]) -> Tier1Features {
    let keydowns: Vec<&KeystrokeEvent> = events
        .iter()
        .filter(|e| e.event_type == "KeyDown" && !e.repeat)
        .collect();

    let keyups: HashMap<u64, &KeystrokeEvent> = events
        .iter()
        .filter(|e| e.event_type == "KeyUp")
        .map(|e| (e.sequence_number, e))
        .collect();

    // Flight times between consecutive keydowns
    let mut flight_times: Vec<f64> = Vec::new();
    let mut digraph_raw: HashMap<String, Vec<f64>> = HashMap::new();
    let mut overlap_count: u32 = 0;
    let mut total_pairs: u32 = 0;

    for pair in keydowns.windows(2) {
        let ft = pair[1].timestamp - pair[0].timestamp;
        if ft > 0.0 && ft <= PAUSE_MAX_MS {
            flight_times.push(ft);
            total_pairs += 1;

            // Digraph key
            let c1 = key_label(&pair[0].key);
            let c2 = key_label(&pair[1].key);
            let key = format!("{}→{}", c1, c2);
            digraph_raw.entry(key).or_default().push(ft);

            // Check for key overlap (roll typing)
            if let Some(keyup) = find_keyup_for(&keyups, pair[0]) {
                if keyup.timestamp > pair[1].timestamp {
                    overlap_count += 1;
                }
            }
        }
    }

    // Hold times
    let mut hold_times: Vec<f64> = Vec::new();
    for kd in &keydowns {
        if let Some(ku) = find_keyup_for(&keyups, kd) {
            let ht = ku.timestamp - kd.timestamp;
            if ht >= 0.0 && ht <= HOLD_MAX_MS {
                hold_times.push(ht);
            }
        }
    }

    // Compute digraph statistics (only for pairs with >= 5 observations)
    let mut digraph_matrix: HashMap<String, DigraphStats> = HashMap::new();
    for (key, mut samples) in digraph_raw {
        if let Some(stats) = DigraphStats::from_samples(&mut samples) {
            digraph_matrix.insert(key, stats);
        }
    }

    // Typing speed (characters per minute)
    let duration_ms = if keydowns.len() >= 2 {
        keydowns.last().unwrap().timestamp - keydowns.first().unwrap().timestamp
    } else {
        0.0
    };
    let typing_speed_cpm = if duration_ms > 0.0 {
        (keydowns.len() as f64 / duration_ms) * 60_000.0
    } else {
        0.0
    };

    Tier1Features {
        flight_time_mean: mean(&flight_times),
        flight_time_std: std_dev(&flight_times),
        flight_time_median: median(&mut flight_times.clone()),
        hold_time_mean: mean(&hold_times),
        hold_time_std: std_dev(&hold_times),
        digraph_count: digraph_matrix.len() as u32,
        digraph_matrix,
        overlap_ratio: if total_pairs > 0 {
            overlap_count as f64 / total_pairs as f64
        } else {
            0.0
        },
        typing_speed_cpm,
    }
}

fn key_label(key: &str) -> String {
    match key {
        " " => "SPC".to_string(),
        "Enter" => "ENT".to_string(),
        "Backspace" => "BS".to_string(),
        "Tab" => "TAB".to_string(),
        "Delete" => "DEL".to_string(),
        _ if key.len() == 1 => key.to_lowercase(),
        other => other.to_string(),
    }
}

fn find_keyup_for<'a>(
    keyups: &'a HashMap<u64, &'a KeystrokeEvent>,
    keydown: &KeystrokeEvent,
) -> Option<&'a KeystrokeEvent> {
    // Try matching by sequence number + 1 (heuristic — keyup often follows keydown)
    // In practice we'd match by key code, but sequence-based is good enough for MVP
    keyups.get(&(keydown.sequence_number + 1)).copied()
}

fn mean(values: &[f64]) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    values.iter().sum::<f64>() / values.len() as f64
}

fn std_dev(values: &[f64]) -> f64 {
    if values.len() < 2 {
        return 0.0;
    }
    let m = mean(values);
    let variance = values.iter().map(|x| (x - m).powi(2)).sum::<f64>() / (values.len() - 1) as f64;
    variance.sqrt()
}

fn median(values: &mut Vec<f64>) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    values.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    values[values.len() / 2]
}
