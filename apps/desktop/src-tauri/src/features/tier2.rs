use serde::{Deserialize, Serialize};
use crate::capture::events::KeystrokeEvent;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tier2Features {
    pub backspace_rate: f64,
    pub delete_rate: f64,
    pub error_burst_count: u32,
    pub mean_error_burst_length: f64,
    pub immediate_correction_ratio: f64,
    pub revision_ratio: f64,
}

pub fn extract(events: &[KeystrokeEvent]) -> Tier2Features {
    let keydowns: Vec<&KeystrokeEvent> = events
        .iter()
        .filter(|e| e.event_type == "KeyDown" && !e.repeat)
        .collect();

    if keydowns.is_empty() {
        return Tier2Features {
            backspace_rate: 0.0,
            delete_rate: 0.0,
            error_burst_count: 0,
            mean_error_burst_length: 0.0,
            immediate_correction_ratio: 0.0,
            revision_ratio: 0.0,
        };
    }

    let total = keydowns.len() as f64;
    let backspace_count = keydowns.iter().filter(|e| e.key == "Backspace").count();
    let delete_count = keydowns.iter().filter(|e| e.key == "Delete").count();
    let correction_count = backspace_count + delete_count;

    // Error bursts: consecutive sequences of backspace/delete keys
    let mut bursts: Vec<u32> = Vec::new();
    let mut current_burst: u32 = 0;
    let mut immediate_corrections: u32 = 0;

    for (i, kd) in keydowns.iter().enumerate() {
        if kd.key == "Backspace" || kd.key == "Delete" {
            current_burst += 1;

            // Immediate correction: backspace right after a character key
            if i > 0 {
                let prev = &keydowns[i - 1];
                if prev.key != "Backspace" && prev.key != "Delete" && prev.key.len() == 1 {
                    let gap = kd.timestamp - prev.timestamp;
                    if gap < 500.0 {
                        immediate_corrections += 1;
                    }
                }
            }
        } else {
            if current_burst > 0 {
                bursts.push(current_burst);
                current_burst = 0;
            }
        }
    }
    if current_burst > 0 {
        bursts.push(current_burst);
    }

    let mean_burst_len = if bursts.is_empty() {
        0.0
    } else {
        bursts.iter().sum::<u32>() as f64 / bursts.len() as f64
    };

    Tier2Features {
        backspace_rate: backspace_count as f64 / total,
        delete_rate: delete_count as f64 / total,
        error_burst_count: bursts.len() as u32,
        mean_error_burst_length: mean_burst_len,
        immediate_correction_ratio: if correction_count > 0 {
            immediate_corrections as f64 / correction_count as f64
        } else {
            0.0
        },
        revision_ratio: correction_count as f64 / total,
    }
}
