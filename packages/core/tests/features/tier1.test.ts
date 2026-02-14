import { describe, it, expect } from "vitest";
import { extractTier1 } from "../../src/features/tier1";
import type { KeystrokeEvent } from "../../src/types/events";

function makeKeydown(
  key: string,
  timestamp: number,
  seq: number,
): KeystrokeEvent {
  return {
    event_type: "KeyDown",
    key,
    code: `Key${key.toUpperCase()}`,
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

function makeKeyup(
  key: string,
  timestamp: number,
  seq: number,
): KeystrokeEvent {
  return { ...makeKeydown(key, timestamp, seq), event_type: "KeyUp" };
}

describe("extractTier1", () => {
  it("returns zeros for empty events", () => {
    const result = extractTier1([]);
    expect(result.flight_time_mean).toBe(0);
    expect(result.hold_time_mean).toBe(0);
    expect(result.typing_speed_cpm).toBe(0);
    expect(result.digraph_count).toBe(0);
    expect(result.overlap_ratio).toBe(0);
  });

  it("computes flight time between keydowns", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("b", 200, 3),
      makeKeydown("c", 300, 5),
    ];
    const result = extractTier1(events);
    expect(result.flight_time_mean).toBe(100);
    expect(result.flight_time_std).toBe(0);
    expect(result.flight_time_median).toBe(100);
  });

  it("computes hold time from keydown-keyup pairs", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeyup("a", 150, 2),
      makeKeydown("b", 200, 3),
      makeKeyup("b", 280, 4),
    ];
    const result = extractTier1(events);
    // hold times: 50, 80 → mean = 65
    expect(result.hold_time_mean).toBe(65);
  });

  it("filters out repeat events", () => {
    const events: KeystrokeEvent[] = [
      makeKeydown("a", 100, 1),
      { ...makeKeydown("a", 110, 2), repeat: true },
      makeKeydown("b", 200, 3),
    ];
    const result = extractTier1(events);
    // Only 2 non-repeat keydowns, flight time = 100
    expect(result.flight_time_mean).toBe(100);
  });

  it("excludes pauses > 30 seconds from flight time", () => {
    const events = [
      makeKeydown("a", 100, 1),
      makeKeydown("b", 200, 3),
      makeKeydown("c", 50200, 5), // 50s gap — excluded
    ];
    const result = extractTier1(events);
    // Only one valid flight time of 100ms
    expect(result.flight_time_mean).toBe(100);
  });

  it("builds digraph matrix for frequent pairs", () => {
    // Create 6 occurrences of a→b (above k_min=5)
    const events: KeystrokeEvent[] = [];
    let seq = 1;
    for (let i = 0; i < 6; i++) {
      events.push(makeKeydown("a", i * 200, seq++));
      events.push(makeKeydown("b", i * 200 + 100, seq++));
    }
    const result = extractTier1(events);
    expect(result.digraph_matrix["a\u2192b"]).toBeDefined();
    expect(result.digraph_matrix["a\u2192b"].count).toBe(6);
    expect(result.digraph_matrix["a\u2192b"].mean).toBe(100);
  });

  it("does not include digraphs with fewer than 5 observations", () => {
    const events = [
      makeKeydown("x", 100, 1),
      makeKeydown("y", 200, 3),
      makeKeydown("x", 300, 5),
      makeKeydown("y", 400, 7),
    ];
    const result = extractTier1(events);
    // Only 2 x→y pairs — below threshold
    expect(result.digraph_matrix["x\u2192y"]).toBeUndefined();
  });

  it("computes typing speed in CPM", () => {
    // 10 keydowns over 1000ms = 10/1000 * 60000 = 600 CPM
    const events: KeystrokeEvent[] = [];
    for (let i = 0; i < 10; i++) {
      events.push(makeKeydown("a", i * 111.11, i * 2 + 1));
    }
    const result = extractTier1(events);
    expect(result.typing_speed_cpm).toBeGreaterThan(0);
  });
});
