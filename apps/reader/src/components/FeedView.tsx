import { useState, useEffect, useCallback } from "react";
import type { BlueskyPost } from "../lib/bluesky-api";
import {
  searchSpeakwritePosts,
  getAuthorFeed,
} from "../lib/bluesky-api";
import {
  parseSpeakwriteFooter,
  type SpeakwritePostMeta,
} from "../lib/speakwrite-filter";
import { PostCard } from "./PostCard";

interface FeedViewProps {
  authorHandle: string | null;
}

interface FeedItem {
  post: BlueskyPost;
  meta: SpeakwritePostMeta;
}

export function FeedView({ authorHandle }: FeedViewProps) {
  const [items, setItems] = useState<FeedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [cursor, setCursor] = useState<string | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const fetchPosts = useCallback(
    async (nextCursor?: string) => {
      try {
        let posts: BlueskyPost[];
        let newCursor: string | undefined;

        if (authorHandle) {
          // Fetch specific author's feed and filter
          const res = await getAuthorFeed(authorHandle, nextCursor);
          posts = res.feed.map((f) => f.post);
          newCursor = res.cursor;
        } else {
          // Search for Speakwrite posts globally
          const res = await searchSpeakwritePosts(nextCursor);
          posts = res.posts;
          newCursor = res.cursor;
        }

        // Filter to only Speakwrite posts and parse metadata
        const speakwriteItems: FeedItem[] = [];
        for (const post of posts) {
          const text = post.record?.text;
          if (!text) continue;
          const meta = parseSpeakwriteFooter(text);
          if (meta) {
            speakwriteItems.push({ post, meta });
          }
        }

        setCursor(newCursor);
        setHasMore(!!newCursor && posts.length > 0);
        return speakwriteItems;
      } catch (e) {
        throw e;
      }
    },
    [authorHandle],
  );

  // Initial load
  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      setError(null);
      setItems([]);
      setCursor(undefined);
      setHasMore(true);

      try {
        const newItems = await fetchPosts();
        if (!cancelled) {
          setItems(newItems);
        }
      } catch (e) {
        if (!cancelled) {
          setError(String(e));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [fetchPosts]);

  const loadMore = async () => {
    if (loadingMore || !hasMore || !cursor) return;
    setLoadingMore(true);

    try {
      const newItems = await fetchPosts(cursor);
      setItems((prev) => [...prev, ...newItems]);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoadingMore(false);
    }
  };

  if (loading) {
    return (
      <div
        className="flex items-center justify-center py-16"
        style={{ fontFamily: "var(--font-mono)" }}
      >
        <span
          style={{
            fontSize: "11px",
            color: "var(--text-secondary)",
            animation: "blink 1s infinite",
          }}
        >
          scanning network_
        </span>
      </div>
    );
  }

  if (error) {
    return (
      <div
        className="px-4 py-8 text-center"
        style={{ fontFamily: "var(--font-mono)" }}
      >
        <div
          style={{
            fontSize: "11px",
            color: "var(--danger)",
            marginBottom: "8px",
          }}
        >
          ERR: {error}
        </div>
        <button
          onClick={() => window.location.reload()}
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            color: "var(--accent)",
            background: "none",
            border: "1px solid var(--accent)",
            padding: "4px 12px",
            cursor: "pointer",
          }}
        >
          retry
        </button>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div
        className="px-4 py-16 text-center"
        style={{ fontFamily: "var(--font-mono)" }}
      >
        <div
          style={{
            fontSize: "12px",
            color: "var(--text-secondary)",
            marginBottom: "8px",
          }}
        >
          {authorHandle
            ? `no verified posts found for @${authorHandle}`
            : "no verified posts found on network"}
        </div>
        <div style={{ fontSize: "10px", color: "#444" }}>
          posts published from Speakwrite will appear here
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* Post count */}
      <div
        className="px-4 py-2"
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--text-secondary)",
          borderBottom: "1px solid var(--border)",
        }}
      >
        {items.length} verified post{items.length !== 1 ? "s" : ""}
        {authorHandle ? ` by @${authorHandle}` : ""}
      </div>

      {/* Posts */}
      {items.map((item) => (
        <PostCard key={item.post.uri} post={item.post} meta={item.meta} />
      ))}

      {/* Load more */}
      {hasMore && (
        <div className="px-4 py-4 text-center">
          <button
            onClick={loadMore}
            disabled={loadingMore}
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "11px",
              color: loadingMore ? "var(--text-secondary)" : "var(--accent)",
              background: "none",
              border: `1px solid ${loadingMore ? "var(--border)" : "var(--accent)"}`,
              padding: "6px 16px",
              cursor: loadingMore ? "default" : "pointer",
            }}
          >
            {loadingMore ? "loading..." : "load more"}
          </button>
        </div>
      )}
    </div>
  );
}
