import type { KeystrokeEvent } from "../types/events";
import type { Tier1Features } from "../types/features";
import { mean, stdDev, median } from "./utils";
import { digraphStatsFromSamples } from "./vector";

const PAUSE_MAX_MS = 30_000;
const HOLD_MAX_MS = 1_000;

function keyLabel(key: string): string {
  switch (key) {
    case " ":
      return "SPC";
    case "Enter":
      return "ENT";
    case "Backspace":
      return "BS";
    case "Tab":
      return "TAB";
    case "Delete":
      return "DEL";
    default:
      return key.length === 1 ? key.toLowerCase() : key;
  }
}

function findKeyupFor(
  keyups: Map<number, KeystrokeEvent>,
  keydown: KeystrokeEvent,
): KeystrokeEvent | null {
  return keyups.get(keydown.sequence_number + 1) ?? null;
}

export function extractTier1(events: KeystrokeEvent[]): Tier1Features {
  const keydowns = events.filter(
    (e) => e.event_type === "KeyDown" && !e.repeat,
  );

  const keyups = new Map<number, KeystrokeEvent>();
  for (const e of events) {
    if (e.event_type === "KeyUp") {
      keyups.set(e.sequence_number, e);
    }
  }

  // Flight times between consecutive keydowns
  const flightTimes: number[] = [];
  const digraphRaw = new Map<string, number[]>();
  let overlapCount = 0;
  let totalPairs = 0;

  for (let i = 0; i < keydowns.length - 1; i++) {
    const ft = keydowns[i + 1].timestamp - keydowns[i].timestamp;
    if (ft > 0 && ft <= PAUSE_MAX_MS) {
      flightTimes.push(ft);
      totalPairs++;

      const c1 = keyLabel(keydowns[i].key);
      const c2 = keyLabel(keydowns[i + 1].key);
      const key = `${c1}\u2192${c2}`;
      let samples = digraphRaw.get(key);
      if (!samples) {
        samples = [];
        digraphRaw.set(key, samples);
      }
      samples.push(ft);

      // Check for key overlap (roll typing)
      const keyup = findKeyupFor(keyups, keydowns[i]);
      if (keyup && keyup.timestamp > keydowns[i + 1].timestamp) {
        overlapCount++;
      }
    }
  }

  // Hold times
  const holdTimes: number[] = [];
  for (const kd of keydowns) {
    const ku = findKeyupFor(keyups, kd);
    if (ku) {
      const ht = ku.timestamp - kd.timestamp;
      if (ht >= 0 && ht <= HOLD_MAX_MS) {
        holdTimes.push(ht);
      }
    }
  }

  // Compute digraph statistics (only for pairs with >= 5 observations)
  const digraphMatrix: Record<string, import("../types/features").DigraphStats> = {};
  for (const [key, samples] of digraphRaw) {
    const stats = digraphStatsFromSamples(samples);
    if (stats) {
      digraphMatrix[key] = stats;
    }
  }

  // Typing speed (characters per minute)
  const durationMs =
    keydowns.length >= 2
      ? keydowns[keydowns.length - 1].timestamp - keydowns[0].timestamp
      : 0;
  const typingSpeedCpm =
    durationMs > 0 ? (keydowns.length / durationMs) * 60_000 : 0;

  return {
    flight_time_mean: mean(flightTimes),
    flight_time_std: stdDev(flightTimes),
    flight_time_median: median(flightTimes),
    hold_time_mean: mean(holdTimes),
    hold_time_std: stdDev(holdTimes),
    digraph_count: Object.keys(digraphMatrix).length,
    digraph_matrix: digraphMatrix,
    overlap_ratio: totalPairs > 0 ? overlapCount / totalPairs : 0,
    typing_speed_cpm: typingSpeedCpm,
  };
}
