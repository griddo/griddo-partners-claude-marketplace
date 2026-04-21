---
name: enrich-university
description: Enrich universities with technology, performance, and academic data. Use when the user wants to add a new university, update existing data, or import a batch of universities.
---

Use the university-atlas MCP tools to enrich university data with external sources.

## Single university enrichment

1. `enrich_university(name: "University Name", country_code: "US")`
   - Optional: `website`, `services` (specific services to run), `save_to_crm`
2. Poll `get_job_status(job_id: "<returned job_id>")` every 5-10 seconds
3. When status is "completed", use `get_university` to see the enriched data

## Batch import (multiple universities)

1. `batch_import(universities: [{"name": "Uni A", "country_code": "US"}, ...])`
   - Max 500 universities per batch
   - Optional: `save_to_crm` (default: false)
2. Poll `get_job_status(job_id: "<returned job_id>")` to track progress
   - Each university is tracked individually in `services_completed` / `services_failed`
3. A batch of 25 universities takes approximately 10-15 minutes

## Available enrichment services

`ror`, `urlscan`, `whatcms`, `eolife`, `crux`, `hibp`, `wikipedia`, `wikidata`, `apollo`, `crtsh`, `dnsdumpster`, `page_count`

## BI Reports

Use `get_report(university_id: "<id>")` to retrieve the latest Business Intelligence report for a university. Reports include academic profile, digital presence analysis, technology assessment, and strategic recommendations.
