---
name: atlas-enrich-university
description: Enrich universities with technology, performance, and academic data. Use when the user wants to add a new university, update existing data, or import a batch of universities.
---

Use the university-atlas MCP tools to enrich university data with external sources.

## Single university enrichment

1. `enrich_university(name: "University Name", country_code: "US")`
   - Optional: `website` to disambiguate institutions with similar names.
2. Poll `get_job_status(job_id: "<returned job_id>")` every 5-10 seconds.
3. When status is `completed`, use `get_university` to see the enriched data.

The enrichment pipeline runs end-to-end and aggregates academic, technological,
performance, and security signals. The mix and weighting of those signals is
managed server-side and may evolve over time — that's how Griddo Atlas keeps
the data fresh and the BI reports sharp. As a caller you don't need to know
which signal sources are active; just trigger the run.

## Subdomain enrichment (when the user asks about subdomains, sites, or sub-pages)

If the user asks something like "enrich the subdomains of UNIBAS",
"refresh sites under harvard.edu", or "get tech data for the subdomains of
University X", **do NOT** invoke `enrich_university` once per subdomain —
that creates institution-level records and pollutes the catalogue.

Instead, follow this flow:

1. `search_universities(query: "...")` → resolve the institution to a
   University in Atlas. Pick the result whose website matches the parent
   domain mentioned by the user.
2. `list_subdomains(university_id: "<id>")` → see what's already on file
   and which entries already have a recent `enrichment_status`.
3. `enrich_subdomains(university_id: "<id>")` → leave `subdomain_urls`
   off to enrich the full catalogue. The server skips subdomains that
   are already enriched, so there's no need to filter on your side.
   - Pass `subdomain_urls: ["a.example.edu", "b.example.edu"]` only when
     the user named specific subdomains. URLs must belong to the
     university's root domain — anything else is rejected.
4. The response includes `total_targeted` and `skipped_already_enriched`
   — use them in your summary to the user before polling for progress.
5. Poll `get_job_status(job_id: "...")` until the batch completes.

If the user mentions a subdomain that Atlas doesn't yet know about,
include it in the `subdomain_urls` list — `enrich_subdomains` will add
it to the catalogue as part of the run.

## Batch import (multiple universities)

1. `batch_import(universities: [{"name": "Uni A", "country_code": "US"}, ...])`
   - Max 500 universities per batch.
2. Poll `get_job_status(job_id: "<returned job_id>")` to track progress.
3. A batch of 25 universities takes approximately 10-15 minutes.

## BI Reports

- **Read existing**: `get_report(university_id: "<id>")` returns the latest Business
  Intelligence report (academic profile, digital presence, technology assessment,
  strategic recommendations).
- **Generate a new one**: delegate to `/university-atlas:bi-report-writer`. That
  skill drafts the full report and persists it via `save_report`, so the next
  `get_report` call returns it. Useful right after enrichment finishes — fresh data
  leads to a sharper analysis.
