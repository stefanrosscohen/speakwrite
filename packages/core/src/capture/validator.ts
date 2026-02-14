import type { KeystrokeEvent } from "../types/events";

/**
 * Validate a keystroke event against sequence/timestamp ordering.
 * Throws on invalid event.
 */
export function validateEvent(
  event: KeystrokeEvent,
  lastSequence: number,
  lastTimestamp: number,
): void {
  if (event.sequence_number <= lastSequence && lastSequence > 0) {
    throw new Error(
      `Sequence regression: got ${event.sequence_number} expected > ${lastSequence}`,
    );
  }

  if (event.timestamp < lastTimestamp - 1) {
    throw new Error(
      `Timestamp regression: got ${event.timestamp} expected >= ${lastTimestamp}`,
    );
  }

  if (event.key === "" && event.code === "") {
    throw new Error("Empty key and code");
  }
}
