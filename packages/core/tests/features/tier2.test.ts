import { describe, it, expect } from "vitest";
import { extractTier2 } from "../../src/features/tier2";
import type { KeystrokeEvent } from "../../src/types/events";

function makeKeydown(
  key: string,
  timestamp: number,
  seq: number,
): KeystrokeEvent {
  return {
    event_type: "KeyDown",
    key,
    code: key === "Backspace" ? "Backspace" : `Key${key.toUpperCase()}`,
    timestamp,
    shift_key: false,
    ctrl_key: false,
    alt_key: false,
    meta_key: false,
    repeat: false,
    is_composing: false,
    sequence_number: seq,
  };
}

describe("extractTier2", () => {
  it("returns zeros for empty events", () => {
    const result = extractTier2([]);
    expect(result.backspace_rate).toBe(0);
    expect(result.delete_rate).toBe(0);
    expect(result.error_burst_count).toBe(0);
    expect(result.revision_ratio).toBe(0);
  });

  it("computes backspace rate", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("b", 200, 2),
      makeKeydown("Backspace", 300, 3),
      makeKeydown("c", 400, 4),
    ];
    const result = extractTier2(events);
    // 1 backspace out of 4 keydowns = 0.25
    expect(result.backspace_rate).toBe(0.25);
    expect(result.revision_ratio).toBe(0.25);
  });

  it("detects error bursts", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("Backspace", 200, 2),
      makeKeydown("Backspace", 250, 3),
      makeKeydown("Backspace", 300, 4),
      makeKeydown("b", 400, 5),
    ];
    const result = extractTier2(events);
    expect(result.error_burst_count).toBe(1);
    expect(result.mean_error_burst_length).toBe(3);
  });

  it("detects multiple error bursts", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("Backspace", 200, 2),
      makeKeydown("Backspace", 250, 3),
      makeKeydown("b", 400, 4),
      makeKeydown("Backspace", 500, 5),
      makeKeydown("c", 600, 6),
    ];
    const result = extractTier2(events);
    expect(result.error_burst_count).toBe(2);
    // burst 1: length 2, burst 2: length 1 → mean = 1.5
    expect(result.mean_error_burst_length).toBe(1.5);
  });

  it("detects immediate corrections (backspace within 500ms)", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("Backspace", 350, 2), // 250ms gap — immediate
      makeKeydown("b", 500, 3),
      makeKeydown("Backspace", 1200, 4), // 700ms gap — not immediate
    ];
    const result = extractTier2(events);
    // 1 immediate correction out of 2 total corrections = 0.5
    expect(result.immediate_correction_ratio).toBe(0.5);
  });

  it("handles no corrections", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("b", 200, 2),
      makeKeydown("c", 300, 3),
    ];
    const result = extractTier2(events);
    expect(result.backspace_rate).toBe(0);
    expect(result.error_burst_count).toBe(0);
    expect(result.immediate_correction_ratio).toBe(0);
    expect(result.revision_ratio).toBe(0);
  });
});
