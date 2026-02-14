import type { KeystrokeEvent } from "../types/events";
import type { Tier2Features } from "../types/features";

export function extractTier2(events: KeystrokeEvent[]): Tier2Features {
  const keydowns = events.filter(
    (e) => e.event_type === "KeyDown" && !e.repeat,
  );

  if (keydowns.length === 0) {
    return {
      backspace_rate: 0,
      delete_rate: 0,
      error_burst_count: 0,
      mean_error_burst_length: 0,
      immediate_correction_ratio: 0,
      revision_ratio: 0,
    };
  }

  const total = keydowns.length;
  const backspaceCount = keydowns.filter(
    (e) => e.key === "Backspace",
  ).length;
  const deleteCount = keydowns.filter((e) => e.key === "Delete").length;
  const correctionCount = backspaceCount + deleteCount;

  // Error bursts: consecutive sequences of backspace/delete keys
  const bursts: number[] = [];
  let currentBurst = 0;
  let immediateCorrections = 0;

  for (let i = 0; i < keydowns.length; i++) {
    const kd = keydowns[i];
    if (kd.key === "Backspace" || kd.key === "Delete") {
      currentBurst++;

      // Immediate correction: backspace right after a character key
      if (i > 0) {
        const prev = keydowns[i - 1];
        if (
          prev.key !== "Backspace" &&
          prev.key !== "Delete" &&
          prev.key.length === 1
        ) {
          const gap = kd.timestamp - prev.timestamp;
          if (gap < 500) {
            immediateCorrections++;
          }
        }
      }
    } else {
      if (currentBurst > 0) {
        bursts.push(currentBurst);
        currentBurst = 0;
      }
    }
  }
  if (currentBurst > 0) {
    bursts.push(currentBurst);
  }

  const meanBurstLen =
    bursts.length === 0
      ? 0
      : bursts.reduce((sum, b) => sum + b, 0) / bursts.length;

  return {
    backspace_rate: backspaceCount / total,
    delete_rate: deleteCount / total,
    error_burst_count: bursts.length,
    mean_error_burst_length: meanBurstLen,
    immediate_correction_ratio:
      correctionCount > 0 ? immediateCorrections / correctionCount : 0,
    revision_ratio: correctionCount / total,
  };
}
