import { Extension } from "@tiptap/core";
import { Plugin, PluginKey } from "@tiptap/pm/state";
import type { KeystrokeEvent } from "../lib/types";
import { recordKeystrokeBatch } from "../lib/commands";

const keystrokeObserverKey = new PluginKey("keystrokeObserver");

let sequenceCounter = 0;
let eventBatch: KeystrokeEvent[] = [];
let batchTimer: ReturnType<typeof setTimeout> | null = null;
const BATCH_INTERVAL_MS = 16; // ~60fps

// Callback for keystroke count updates
let onKeystrokesBatched: ((count: number) => void) | null = null;

function recordEvent(type: string, event: Event) {
  const ke = event as KeyboardEvent;
  const keystrokeEvent: KeystrokeEvent = {
    event_type: type,
    key: ke.key ?? "",
    code: ke.code ?? "",
    timestamp: performance.now() + performance.timeOrigin,
    shift_key: ke.shiftKey ?? false,
    ctrl_key: ke.ctrlKey ?? false,
    alt_key: ke.altKey ?? false,
    meta_key: ke.metaKey ?? false,
    repeat: ke.repeat ?? false,
    is_composing: ke.isComposing ?? false,
    sequence_number: sequenceCounter++,
  };

  eventBatch.push(keystrokeEvent);

  if (!batchTimer) {
    batchTimer = setTimeout(flushBatch, BATCH_INTERVAL_MS);
  }
}

async function flushBatch() {
  batchTimer = null;
  if (eventBatch.length === 0) return;

  const batch = eventBatch;
  eventBatch = [];

  try {
    await recordKeystrokeBatch(batch);
    onKeystrokesBatched?.(batch.length);
  } catch (e) {
    console.error("Failed to record keystrokes:", e);
  }
}

export const KeystrokeObserver = Extension.create({
  name: "keystrokeObserver",

  addOptions() {
    return {
      onKeystrokesBatched: null as ((count: number) => void) | null,
    };
  },

  onCreate() {
    onKeystrokesBatched = this.options.onKeystrokesBatched;
  },

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: keystrokeObserverKey,
        props: {
          handleDOMEvents: {
            keydown: (_view, event) => {
              recordEvent("KeyDown", event);
              return false;
            },
            keyup: (_view, event) => {
              recordEvent("KeyUp", event);
              return false;
            },
            compositionstart: (_view, event) => {
              recordEvent("CompositionStart", event);
              return false;
            },
            compositionend: (_view, event) => {
              recordEvent("CompositionEnd", event);
              return false;
            },
            paste: (_view, event) => {
              recordEvent("Paste", event);
              return false;
            },
            cut: (_view, event) => {
              recordEvent("Cut", event);
              return false;
            },
          },
        },
      }),
    ];
  },
});
