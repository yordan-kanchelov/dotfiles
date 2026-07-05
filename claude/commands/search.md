Search the web using Exa for real-time, up-to-date information.

**Usage:**
- `/search <query>` - Search with the given query
- `/search` - I'll ask you what to search for

**Workflow:**

1. **Get search query:**
   - If $ARGUMENTS is provided, use it as the search query
   - Otherwise, ask: "What would you like me to search for?"

2. **Perform the search:**
   - Use the `web_search_exa` MCP tool with these parameters:
     - `query`: the user's search query
     - `type`: `"deep"` (multi-query deep search with structured outputs, 4-12s)
     - `num_results`: 10
     - `contents`: `{ "text": { "max_characters": 20000 } }` (full text extraction)
   - The `deep` search type runs multiple query variations and ranks combined results for thorough coverage

3. **Structured outputs (when appropriate):**
   - If the user is looking for specific structured data (e.g. list of companies, people, features), use the `outputSchema` parameter to define the shape of results
   - Deep search supports `outputSchema` with field-level citations and confidence scores via `output.grounding`
   - Schema controls: `type`, `description`, `required`, `properties`, `items`

4. **Category filters (when appropriate):**
   - For people searches: add `category: "people"` (use singular form, describe what they work on)
   - For company searches: add `category: "company"` (simple entity queries)
   - For news: add `category: "news"`
   - For academic papers: add `category: "research paper"`
   - Only add a category when the query clearly fits one — categories can be restrictive

5. **Domain filtering (when appropriate):**
   - Use `includeDomains` to target specific authoritative sources (e.g. `["arxiv.org", "github.com"]`)
   - Use `excludeDomains` to filter out low-quality domains
   - Usually not needed — Exa's neural search finds relevant results without domain restrictions

6. **Content freshness:**
   - For breaking news or real-time data, add `maxAgeHours: 1` or `maxAgeHours: 0` (always livecrawl)
   - For daily-fresh content, use `maxAgeHours: 24`
   - For historical/static content, omit it (default behavior is fine)

7. **Present results:**
   - Summarize key findings in a clear, structured format
   - Include source URLs for each finding so the user can verify
   - Highlight the most relevant and recent information
   - If structured outputs were used, present the grounded data with confidence levels
   - If the results don't fully answer the query, suggest follow-up searches

**Parameter reference (avoid these mistakes):**
- `useAutoprompt` is deprecated — do not use
- `includeUrls`/`excludeUrls` do not exist — use `includeDomains`/`excludeDomains`
- `stream: true` is not supported on /search
- `text`/`highlights` must be nested inside `contents` (e.g. `"contents": {"text": true}`)
- Use `maxAgeHours` instead of deprecated `livecrawl`
- Use `maxCharacters` instead of deprecated `numSentences`/`highlightsPerUrl`

**Example:**
```
/search latest TypeScript 5.8 features
/search how to configure Playwright MCP server
/search AI startups in healthcare
```
