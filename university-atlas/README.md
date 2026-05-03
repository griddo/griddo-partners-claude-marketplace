# University Atlas — Claude Code Plugin

Search, enrich, and analyze university data via Griddo Atlas.

## What it does

Connects to the Griddo Atlas MCP server, giving you access to:

- **Search** 150+ universities across database and academic registries
- **Enrich** universities with technology stacks, web performance, academic data
- **Import** batches of universities from lists or CSV
- **Read** BI reports with strategic recommendations
- **Draft & persist** new BI reports — the `bi-report-writer` skill orchestrates the
  full flow (resolve → fetch canonical prompt → research → save) so the report lives
  in Atlas and is retrievable by everyone with access to that university

## Installation

### 1. Get your API key

Request a long-lived API key from your Griddo administrator. The key is a JWT
of `type: mcp_api_key` issued for your user (role: `admin`, `editor`, or
`viewer` depending on what you need to do). Treat it like a password — it
gives access to your Atlas data.

### 2. Set it in your shell environment

Add to your `~/.zshrc` / `~/.bashrc` / `~/.config/fish/config.fish`:

```bash
export UNIVERSITY_ATLAS_API_KEY="eyJhbGciOi..."   # the JWT you received
```

Reload your shell (`source ~/.zshrc`) **before launching Claude Code**, otherwise
the plugin won't see the variable.

### 3. Add the marketplace + install the plugin

```bash
# Add the Griddo partner marketplace
/plugin marketplace add griddo/griddo-partners-claude-marketplace

# Install the plugin
/plugin install university-atlas@griddo-claude-marketplace
```

The plugin reads `${UNIVERSITY_ATLAS_API_KEY}` from your shell at startup and
sends it as a `Authorization: Bearer …` header on every request. No browser
flow, no OAuth, no manual token refresh.

## Tools

| Tool | Description |
|------|-------------|
| `search_universities` | Search by name or universal ID |
| `get_university` | Get full university profile |
| `enrich_university` | Trigger enrichment for a university |
| `batch_import` | Import and enrich multiple universities |
| `get_job_status` | Track enrichment progress |
| `get_report` | Get latest BI report (read) |
| `get_report_template` | Fetch the canonical BI report prompt + validation contract (used by `bi-report-writer`) |
| `save_report` | Persist a freshly-drafted BI report (used by `bi-report-writer`) |

## Skills

| Skill | Description |
|------|-------------|
| `atlas-search-university` | Search and retrieve university data |
| `atlas-enrich-university` | Trigger enrichment for one or many universities |
| `bi-report-writer` | Draft a comprehensive BI report on a university and persist it to Atlas |

## Authentication

Uses a long-lived **API key** (JWT, `type: mcp_api_key`) shipped via the
`UNIVERSITY_ATLAS_API_KEY` environment variable. The plugin sends it as
a `Authorization: Bearer …` header on every MCP request; the Atlas
backend decodes the JWT and applies the user's role.

Why not OAuth? Earlier versions of this plugin relied on Claude Code's
built-in OAuth flow (`type: http` + automatic discovery). That flow has
a known bug — the PKCE state is lost between `authenticate` and
`complete_authentication` ("No OAuth flow is in progress"), which left
the plugin unable to obtain tokens. A static-bearer setup sidesteps the
client-side state-persistence issue entirely and is also faster on
startup (no redirect dance).

### Rotation / revocation

API keys don't expire (`type: mcp_api_key` JWTs have no `exp` claim by
design). To rotate or revoke a key, contact your Griddo admin — the
backend's user/auth system can revoke a specific JWT or rotate the
shared signing secret.

### Troubleshooting

- **`401 Unauthorized` on every tool call**: the variable isn't set, or
  the key was revoked. Check `echo $UNIVERSITY_ATLAS_API_KEY` in the
  same shell that launched Claude Code.
- **Tools don't appear in Claude Code**: the plugin failed to start.
  Run `/mcp` to see error details.
- **Permission denied on a specific tool**: the API key was issued for
  a role (e.g. `viewer`) that lacks permission for that endpoint.
  Request a higher-role key.
