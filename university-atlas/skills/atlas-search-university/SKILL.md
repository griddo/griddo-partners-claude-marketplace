---
name: atlas-search-university
description: Search and retrieve university data from Griddo Atlas. Use when the user asks about a university, wants to find institutions by name, or needs university profiles.
---

Use the university-atlas MCP tools to search and retrieve university data.

## Workflow

1. **Search**: Use `search_universities` with the university name or CRM ID
2. **Get details**: Use `get_university` with the ID from search results to get the full profile

## Available data in a university profile

- **Identity**: Name, acronym, country, city, type, founding year
- **Digital footprint**: Website, LinkedIn, social media, subdomain map
- **Technology assessment**: CMS platform, hosting, plus security and connection signals
- **Web performance**: real-user Core Web Vitals (loading, interactivity, layout stability) with mobile/desktop breakdown
- **Academic profile**: official identifiers, student and staff counts, where available
- **BI Report** (when available): retrievable via `get_report(university_id)` — full strategic analysis

## Example

User: "Tell me about IE University"

1. `search_universities(query: "IE University")`
2. Pick the matching result, note the `id`
3. `get_university(university_id: "<id>")`
4. Present the relevant information
