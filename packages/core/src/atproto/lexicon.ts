/**
 * Custom AT Protocol lexicon for Speakwrite proof records.
 * This defines the schema for io.speakwrite.proof records stored on a user's PDS.
 */
export const SPEAKWRITE_PROOF_LEXICON = {
  lexicon: 1,
  id: "io.speakwrite.proof",
  defs: {
    main: {
      type: "record",
      key: "tid",
      record: {
        type: "object",
        required: [
          "contentHash",
          "bindingHash",
          "chainLength",
          "totalKeystrokes",
          "proofBundle",
          "createdAt",
        ],
        properties: {
          contentHash: {
            type: "string",
            description: "SHA-256 hash of the document content",
          },
          bindingHash: {
            type: "string",
            description: "Content-binding commitment hash (chain tip)",
          },
          chainLength: {
            type: "integer",
            description: "Number of behavioral commitments in the chain",
          },
          totalKeystrokes: {
            type: "integer",
            description: "Total keystrokes recorded across all sessions",
          },
          proofBundle: {
            type: "string",
            description:
              "JSON-encoded proof bundle containing the full commitment chain",
          },
          verifierUrl: {
            type: "string",
            format: "uri",
            description: "URL to verify this proof",
          },
          createdAt: {
            type: "string",
            format: "datetime",
          },
        },
      },
    },
  },
} as const;

export const PROOF_COLLECTION = "io.speakwrite.proof";
