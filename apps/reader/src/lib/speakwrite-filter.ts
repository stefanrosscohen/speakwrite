/**
 * Detects and parses Speakwrite proof footers in Bluesky post text.
 *
 * Footer format (from publishProofPost):
 *   \n\n✅ 847 keystrokes · 3 commitments
 */

export const SPEAKWRITE_FOOTER_RE =
  /\u2705\s*([\d,]+)\s*keystrokes\s*\u00b7\s*(\d+)\s*commitments?\s*$/;

export interface SpeakwritePostMeta {
  keystrokes: number;
  commitments: number;
  contentText: string;
}

/**
 * Parse a Speakwrite footer from post text.
 * Returns null if the text does not contain a valid footer.
 */
export function parseSpeakwriteFooter(
  text: string,
): SpeakwritePostMeta | null {
  const match = text.match(SPEAKWRITE_FOOTER_RE);
  if (!match) return null;

  const keystrokes = parseInt(match[1].replace(/,/g, ""), 10);
  const commitments = parseInt(match[2], 10);
  const contentText = text.replace(SPEAKWRITE_FOOTER_RE, "").trimEnd();

  return { keystrokes, commitments, contentText };
}

/**
 * Quick check if a post text contains a Speakwrite footer.
 */
export function isSpeakwritePost(text: string): boolean {
  return SPEAKWRITE_FOOTER_RE.test(text);
}
