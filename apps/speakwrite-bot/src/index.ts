import 'dotenv/config';
import express from 'express';
import { AtpAgent } from '@atproto/api';
import { pollNotifications } from './bot.js';
import { handleFeedQuery } from './feed-query.js';

const POLL_INTERVAL = 30_000; // 30 seconds

// Rate limiter: sliding window per IP
const rateLimitMap = new Map<string, number[]>();
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX = 10; // 10 requests per minute

function rateLimit(req: express.Request, res: express.Response, next: express.NextFunction): void {
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const timestamps = rateLimitMap.get(ip) || [];
  const recent = timestamps.filter(t => now - t < RATE_LIMIT_WINDOW_MS);

  if (recent.length >= RATE_LIMIT_MAX) {
    res.status(429).json({ error: 'Too many requests. Try again later.' });
    return;
  }

  recent.push(now);
  rateLimitMap.set(ip, recent);
  next();
}

// Clean up rate limit map every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [ip, timestamps] of rateLimitMap) {
    const recent = timestamps.filter(t => now - t < RATE_LIMIT_WINDOW_MS);
    if (recent.length === 0) rateLimitMap.delete(ip);
    else rateLimitMap.set(ip, recent);
  }
}, 5 * 60_000);

// CORS: only allow requests from speakwrite.io
const ALLOWED_ORIGINS = [
  'https://speakwrite.io',
  'https://www.speakwrite.io',
];

function cors(req: express.Request, res: express.Response, next: express.NextFunction): void {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (req.method === 'OPTIONS') { res.status(204).end(); return; }
  next();
}

// Security headers
function securityHeaders(_req: express.Request, res: express.Response, next: express.NextFunction): void {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
}

// API key auth for feed-query (requires FEED_QUERY_API_KEY env var)
function feedQueryAuth(req: express.Request, res: express.Response, next: express.NextFunction): void {
  const apiKey = process.env.FEED_QUERY_API_KEY;
  if (!apiKey) {
    // If no API key is configured, allow iOS app origin-based requests only
    const origin = req.headers.origin;
    if (origin && ALLOWED_ORIGINS.includes(origin)) { next(); return; }
    // Also allow requests with the app's bundle-based auth header
    const authHeader = req.headers.authorization;
    if (authHeader === 'Bearer io.speakwrite.app') { next(); return; }
    res.status(403).json({ error: 'Forbidden' });
    return;
  }
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${apiKey}`) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }
  next();
}

async function main() {
  const service = process.env.BSKY_SERVICE || 'https://bsky.social';
  const identifier = process.env.BSKY_IDENTIFIER;
  const password = process.env.BSKY_PASSWORD;

  if (!identifier || !password) {
    console.error('Missing BSKY_IDENTIFIER or BSKY_PASSWORD');
    process.exit(1);
  }

  // Health server
  const app = express();
  app.use(securityHeaders);
  app.use(cors);
  app.use(express.json({ limit: '10kb' }));
  app.set('trust proxy', true);
  const port = parseInt(process.env.PORT || '3000', 10);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'verify-speakwrite-bot' });
  });

  app.post('/api/feed-query', rateLimit, feedQueryAuth, handleFeedQuery);

  app.listen(port, '0.0.0.0', () => {
    console.log(`Health server listening on :${port}`);
  });

  // AT Protocol login
  const agent = new AtpAgent({ service });
  await agent.login({ identifier, password });
  console.log(`Logged in as ${agent.session?.handle} (${agent.session?.did})`);

  // Ensure bot profile is set
  try {
    await agent.upsertProfile((existing) => {
      const description = 'Cryptographic proof-of-humanity verification bot. Tag me on any post to check if it was typed by a real human on a real device.\n\nhttps://www.speakwrite.io';
      const displayName = 'Speakwrite Verify';
      const current = existing ?? {};
      if (current.description === description && current.displayName === displayName) {
        return current;
      }
      return { ...current, description, displayName };
    });
    console.log('Bot profile updated');
  } catch (err) {
    console.error('Failed to update bot profile:', err);
  }

  // Start polling
  console.log(`Polling every ${POLL_INTERVAL / 1000}s...`);
  await pollNotifications(agent);
  setInterval(() => pollNotifications(agent), POLL_INTERVAL);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
