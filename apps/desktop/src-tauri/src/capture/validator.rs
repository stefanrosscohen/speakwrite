use super::events::KeystrokeEvent;

pub fn validate_event(event: &KeystrokeEvent, last_sequence: u64, last_timestamp: f64) -> Result<(), String> {
    if event.sequence_number <= last_sequence && last_sequence > 0 {
        return Err(format!(
            "Sequence regression: got {} expected > {}",
            event.sequence_number, last_sequence
        ));
    }

    if event.timestamp < last_timestamp - 1.0 {
        return Err(format!(
            "Timestamp regression: got {} expected >= {}",
            event.timestamp, last_timestamp
        ));
    }

    if event.key.is_empty() && event.code.is_empty() {
        return Err("Empty key and code".to_string());
    }

    Ok(())
}
