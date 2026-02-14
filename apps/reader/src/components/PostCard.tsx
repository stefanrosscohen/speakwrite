import { useEffect, useState } from "react";
import type { BlueskyPost } from "../lib/bluesky-api";
import { rkeyFromUri } from "../lib/bluesky-api";
import type { SpeakwritePostMeta } from "../lib/speakwrite-filter";
import { VerificationBadge } from "./VerificationBadge";
import type { VerificationStatus } from "../lib/verification";
import { attemptVerification } from "../lib/verification";

interface Props {
  post: BlueskyPost;
  meta: SpeakwritePostMeta;
}

function timeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = now - then;

  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;

  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d`;

  const months = Math.floor(days / 30);
  return `${months}mo`;
}

export function PostCard({ post, meta }: Props) {
  const [verificationStatus, setVerificationStatus] =
    useState<VerificationStatus>({
      type: "footer_only",
      keystrokes: meta.keystrokes,
      commitments: meta.commitments,
    });

  const rkey = rkeyFromUri(post.uri);
  const bskyUrl = `https://bsky.app/profile/${post.author.handle}/post/${rkey}`;

  // Attempt to find and verify a proof record asynchronously
  useEffect(() => {
    let cancelled = false;

    async function verify() {
      const result = await attemptVerification(
        post.author.did,
        meta.contentText,
      );
      if (!cancelled && result) {
        setVerificationStatus(result);
      }
    }

    verify();
    return () => {
      cancelled = true;
    };
  }, [post.author.did, meta.contentText]);

  return (
    <article
      style={{
        padding: "16px",
        borderBottom: "1px solid var(--border)",
        background: "var(--bg-secondary)",
      }}
    >
      {/* Author row */}
      <div className="flex items-center gap-3 mb-3">
        {post.author.avatar ? (
          <img
            src={post.author.avatar}
            alt=""
            style={{
              width: "28px",
              height: "28px",
              borderRadius: "0",
              border: "1px solid var(--border)",
              objectFit: "cover",
            }}
          />
        ) : (
          <div
            style={{
              width: "28px",
              height: "28px",
              border: "1px solid var(--border)",
              background: "var(--bg-surface)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontFamily: "var(--font-mono)",
              fontSize: "10px",
              color: "var(--accent)",
            }}
          >
            {post.author.handle.charAt(0).toUpperCase()}
          </div>
        )}

        <div className="flex flex-col">
          {post.author.displayName && (
            <span
              style={{
                fontFamily: "var(--font-mono)",
                fontSize: "12px",
                fontWeight: 600,
                color: "var(--text-primary)",
              }}
            >
              {post.author.displayName}
            </span>
          )}
          <span
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "11px",
              color: "var(--accent)",
            }}
          >
            @{post.author.handle}
          </span>
        </div>

        <span
          style={{
            marginLeft: "auto",
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            color: "var(--text-secondary)",
          }}
        >
          {timeAgo(post.record.createdAt)}
        </span>
      </div>

      {/* Post content (footer stripped) */}
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "13px",
          lineHeight: "1.7",
          color: "var(--text-primary)",
          marginBottom: "12px",
          whiteSpace: "pre-wrap",
          wordBreak: "break-word",
        }}
      >
        {meta.contentText}
      </div>

      {/* Verification badge + link */}
      <div className="flex items-center justify-between">
        <VerificationBadge status={verificationStatus} />

        <a
          href={bskyUrl}
          target="_blank"
          rel="noopener noreferrer"
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            color: "var(--text-secondary)",
            textDecoration: "none",
            borderBottom: "1px dashed var(--border)",
          }}
        >
          bsky.app
        </a>
      </div>
    </article>
  );
}
