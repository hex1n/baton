---
name: x-reader
description: Use when the user pastes an X (Twitter) link and wants to read, analyze, or summarize the tweet or article content. Triggers on URLs containing x.com or twitter.com with a status ID or article ID.
---

# X/Twitter Link Reader

## Overview

Use **Jina Reader** (`r.jina.ai`) as the primary fetcher — it renders JavaScript and returns full content as markdown, covering both regular tweets and X Articles. Fall back to Twitter syndication/oEmbed APIs only when Jina fails.

**Not for** general web scraping — use WebFetch directly for non-X URLs.

## Quick Reference

| URL Pattern | Jina | Syndication | oEmbed |
|---|---|---|---|
| `x.com/{user}/status/{id}` | ✅ | ✅ | ✅ |
| `twitter.com/{user}/status/{id}` | ✅ | ✅ | ✅ |
| `x.com/i/article/{id}` | ✅ | ❌ | ❌ |

Strip query params (`?s=20`, `?t=...`) before processing.

## Steps

1. **Fetch via Jina Reader** (primary, works for tweets AND articles):
   ```
   https://r.jina.ai/{ORIGINAL_URL}
   ```

2. **If Jina fails or returns insufficient data for a regular tweet**, fall back to syndication API. Extract the tweet ID (numeric string after `/status/`) and fetch:
   ```
   https://cdn.syndication.twimg.com/tweet-result?id={TWEET_ID}&token=0
   ```

3. **If syndication also fails**, try oEmbed:
   ```
   https://publish.twitter.com/oembed?url={ORIGINAL_URL}
   ```

4. **Present results** clearly:
   - Author name and handle
   - Full text / article body
   - Date/time
   - Engagement metrics (if available)
   - Media descriptions (if available)
   - Thread context (if it's a reply)

**Multiple links:** Fetch all in parallel using concurrent WebFetch calls.

## Common Mistakes

| Issue | Fix |
|-------|-----|
| Jina returns error/empty | Fall back to syndication API, then oEmbed |
| 404 from syndication API | Tweet may be deleted or private. Try oEmbed. If all fail, tell the user. |
| X Article via syndication/oEmbed | Must use Jina Reader — only method that supports articles |
| URL has extra params | Strip query params before extracting tweet ID |
