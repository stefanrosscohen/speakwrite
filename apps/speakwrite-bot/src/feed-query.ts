import { Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic();

const SYSTEM_PROMPT = `You generate search queries for Bluesky's app.bsky.feed.searchPosts API.

Given a user's description of what they want to see, return 3-5 short search queries that will surface relevant posts.

Rules:
- Each query should be 1-4 words
- Use different angles/synonyms to maximize coverage
- Return ONLY raw JSON, no markdown fences
- Format: { "queries": ["query1", "query2", ...], "description": "brief one-line summary of the interest" }`;

export async function handleFeedQuery(req: Request, res: Response): Promise<void> {
  const { prompt } = req.body ?? {};

  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    res.status(400).json({ error: 'prompt is required and must be a non-empty string' });
    return;
  }

  if (prompt.length > 500) {
    res.status(400).json({ error: 'prompt must be 500 characters or less' });
    return;
  }

  try {
    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 200,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: prompt.trim() }],
    });

    const text = response.content[0];
    if (text.type !== 'text') {
      res.status(500).json({ error: 'Unexpected response format from Claude' });
      return;
    }

    // Strip markdown fences if Claude wraps the JSON
    const raw = text.text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
    const parsed = JSON.parse(raw);

    if (!Array.isArray(parsed.queries) || parsed.queries.length === 0) {
      res.status(500).json({ error: 'Invalid query format from Claude' });
      return;
    }

    res.json({
      queries: parsed.queries.slice(0, 5),
      description: parsed.description || prompt.trim(),
    });
  } catch (err) {
    console.error('Feed query error:', err);
    res.status(500).json({ error: 'Failed to generate feed queries' });
  }
}
