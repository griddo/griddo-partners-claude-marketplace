# Release checklist — griddo-partners-claude-marketplace

Step 0 of `/marketplace-release:release`. Apply every item before running the release script.
Fix anything stale in its own commit first (`docs: refresh README to current skills`); the script
requires a clean tree. Leave version numbers alone; the release handles them.

This repo is **public**. Maintainers enable the `marketplace-release` plugin in their own user
settings, not in a committed `.claude/settings.json`, which would point every visitor to a
marketplace they can't reach.

## university-atlas

- Enumerate what ships (`ls university-atlas/skills/`). Every skill is described in
  `university-atlas/README.md`, nothing removed or renamed is still listed, and the descriptions
  match what the skills now do.
- The row in `README.md` still describes the plugin, including how it connects (`.mcp.json`:
  the Griddo Atlas MCP and its OAuth flow).
- This marketplace is for partner universities: nothing internal to Griddo (sales process, client
  names, internal URLs or credentials) appears in what ships.
