import { describe, it, expect } from "vitest";
import { validateEvent } from "../../src/capture/validator";
import type { KeystrokeEvent } from "../../src/types/events";

function makeEvent(overrides: Partial<KeystrokeEvent> = {}): KeystrokeEvent {
  return {
    event_type: "KeyDown",
    key: "a",
    code: "KeyA",
    timestamp: 100,
    shift_key: false,
    ctrl_key: false,
    alt_key: false,
    meta_key: false,
    repeat: false,
    is_composing: false,
    sequence_number: 1,
    ...overrides,
  };
}

describe("validateEvent", () => {
  it("accepts valid event", () => {
    expect(() => validateEvent(makeEvent(), 0, 0)).not.toThrow();
  });

  it("rejects sequence regression", () => {
    expect(() =>
      validateEvent(makeEvent({ sequence_number: 1 }), 2, 0),
    ).toThrow("Sequence regression");
  });

  it("allows first event with sequence 1", () => {
    expect(() =>
      validateEvent(makeEvent({ sequence_number: 1 }), 0, 0),
    ).not.toThrow();
  });

  it("rejects timestamp regression beyond 1ms tolerance", () => {
    expect(() =>
      validateEvent(makeEvent({ timestamp: 50 }), 0, 100),
    ).toThrow("Timestamp regression");
  });

  it("allows timestamp within 1ms tolerance", () => {
    expect(() =>
      validateEvent(makeEvent({ timestamp: 99.5 }), 0, 100),
    ).not.toThrow();
  });

  it("rejects empty key and code", () => {
    expect(() =>
      validateEvent(makeEvent({ key: "", code: "" }), 0, 0),
    ).toThrow("Empty key and code");
  });

  it("allows empty key if code is present", () => {
    expect(() =>
      validateEvent(makeEvent({ key: "", code: "KeyA" }), 0, 0),
    ).not.toThrow();
  });
});
