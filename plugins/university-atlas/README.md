# University Atlas — Claude Code Plugin

Search, enrich, and analyze university data via Griddo Atlas.

## What it does

Connects to the Griddo Atlas MCP server, giving you access to:

- **Search** 150+ universities across database, CRM, and academic registries
- **Enrich** universities with technology stacks, web performance, academic data
- **Import** batches of universities from lists or CSV
- **Read** BI reports with strategic recommendations

## Installation

```bash
# Add the Griddo marketplace
/plugin marketplace add griddo/atlas-marketplace

# Install the plugin
/plugin install university-atlas@griddo-atlas
```

On first use, your browser will open for authentication via Griddo Atlas.

## Tools

| Tool | Description |
|------|-------------|
| `search_universities` | Search by name or CRM ID |
| `get_university` | Get full university profile |
| `enrich_university` | Trigger enrichment for a university |
| `batch_import` | Import and enrich multiple universities |
| `get_job_status` | Track enrichment progress |
| `get_report` | Get latest BI report |

## Authentication

Uses OAuth 2.1. On first tool call, Claude Code will open your browser
to authenticate with your Griddo Atlas credentials. Tokens refresh
automatically — no manual token management needed.
