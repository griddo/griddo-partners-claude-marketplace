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

### 1. Get your Griddo Atlas account

Ask your Griddo account manager to provision a personal user account in Atlas
for you. You'll receive an email + initial password, and a role (`viewer`,
`editor`, or `admin`) that determines which tools you can call.

> Per-individual accounts (not per-organization tokens) means your usage is
> attributable, your access can be revoked individually if you change companies,
> and your role can be tuned without affecting your colleagues.

### 2. Add the marketplace + install the plugin

```bash
# Add the Griddo partner marketplace
/plugin marketplace add griddo/griddo-partners-claude-marketplace

# Install the plugin
/plugin install university-atlas@griddo-partners-claude-marketplace
```

### 3. Connect (one-time, OAuth flow)

The first time Claude Code calls a tool from this plugin, it'll detect that
the Atlas MCP server requires authentication and open a browser tab pointing
to the Griddo Atlas login page. Sign in with the credentials from step 1 and
approve the connection.

After that, Claude Code persists the access + refresh tokens locally. Tokens
refresh automatically — no manual setup, no env vars, no token paste.

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

Which tools you can actually invoke depends on your account's role. The server
returns 401/403 when you call something outside your scope — the skills handle
those errors gracefully.

## Skills

| Skill | Description |
|------|-------------|
| `atlas-search-university` | Search and retrieve university data |
| `atlas-enrich-university` | Trigger enrichment for one or many universities |
| `bi-report-writer` | Draft a comprehensive BI report on a university and persist it to Atlas |

## Authentication

Uses **OAuth 2.1** with PKCE against `https://api.atlas.griddo.io/mcp/`. Claude
Code handles the flow automatically: it discovers the auth server via
`/.well-known/oauth-authorization-server`, registers itself as a client (DCR),
opens a browser for login, and stores the access + refresh tokens.

Each tool call carries an `Authorization: Bearer <jwt>` header; the JWT
encodes your user ID, email, and role, so every request is attributable to
you (visible in Atlas's activity log).

### Tokens & sessions

- **Access token** lifetime: 1 hour. Refreshed automatically by Claude Code.
- **Refresh token** lifetime: 30 days. After that, you'll be asked to log in
  again in the browser.
- **Revocation**: contact your Griddo account manager. Disabling your Atlas
  account immediately invalidates any active tokens.

### Troubleshooting

- **`401 Unauthorized` on every tool call after a long break**: refresh token
  expired (≥ 30 days unused). Re-trigger any tool to start a fresh login flow.
- **Browser doesn't open on first connect, or login page 404s**: your Claude
  Code version may not support OAuth-discovered MCP servers. Update to the
  latest Claude Desktop / Claude Code build.
- **`403 Forbidden` on a specific tool**: your account's role doesn't allow
  that operation (e.g. `viewer` can't trigger enrichment). Ask your Griddo
  account manager to upgrade your role.
- **Tools don't appear in Claude Code**: the plugin failed to start. Run
  `/mcp` to see error details (likely OAuth discovery failure if the Atlas
  server is unreachable).
