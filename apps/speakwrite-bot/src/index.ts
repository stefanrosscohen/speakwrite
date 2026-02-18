import 'dotenv/config';
import express from 'express';
import { AtpAgent } from '@atproto/api';
import { pollNotifications } from './bot.js';

const POLL_INTERVAL = 30_000; // 30 seconds

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
  const port = parseInt(process.env.PORT || '3000', 10);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'verify-speakwrite-bot' });
  });

  app.listen(port, '0.0.0.0', () => {
    console.log(`Health server listening on :${port}`);
  });

  // AT Protocol login
  const agent = new AtpAgent({ service });
  await agent.login({ identifier, password });
  console.log(`Logged in as ${agent.session?.handle} (${agent.session?.did})`);

  // Start polling
  console.log(`Polling every ${POLL_INTERVAL / 1000}s...`);
  await pollNotifications(agent);
  setInterval(() => pollNotifications(agent), POLL_INTERVAL);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
