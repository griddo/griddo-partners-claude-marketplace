---
name: search-university
description: Search and retrieve university data from Griddo Atlas. Use when the user asks about a university, wants to find institutions by name, or needs university profiles.
---

Use the university-atlas MCP tools to search and retrieve university data.

## Workflow

1. **Search**: Use `search_universities` with the university name or CRM ID
2. **Get details**: Use `get_university` with the ID from search results to get the full profile

## Available data in a university profile

- **Basic info**: Name, acronym, country, city, type, founding year
- **Technology**: CMS platform, hosting, subdomains, security (SSL, HIBP breaches)
- **Web performance**: CrUX Core Web Vitals (LCP, CLS, INP) with form factor breakdown
- **Academic**: ROR data, Wikidata, Wikipedia, student/staff counts
- **Digital presence**: Website, LinkedIn, social media
- **CRM**: Pipedrive linkage, labels, owner

## Example

User: "Tell me about IE University"

1. `search_universities(query: "IE University")`
2. Pick the matching result, note the `id`
3. `get_university(university_id: "<id>")`
4. Present the relevant information
