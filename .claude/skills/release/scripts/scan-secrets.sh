#!/usr/bin/env bash
set -euo pipefail

# scan-secrets.sh — Detect likely exposed credentials in tracked files.
#
# Called by release.sh as a gate before version bumps. Can also be run
# standalone for spot checks.
#
# Exit codes:
#   0  Clean
#   1  Findings detected (details on stdout/stderr)
#   2  Error

OUTPUT="text"

show_help() {
  cat <<'HELP'
Usage: scan-secrets.sh [--json] [--help]

Scan git-tracked files for likely exposed credentials. Matches two classes:

  1. Well-known credential formats:
     AWS keys (AKIA...), GitHub tokens (ghp_...), SendGrid keys,
     Slack tokens, Google API keys, Stripe live keys, private key
     blocks, and JWTs.

  2. Credential-named variable assignments:
     var names containing password/passwd/pwd/secret/apikey/token/
     credential/mailpass/sendgrid assigned to a 12+ character value
     that is not a bracketed placeholder (e.g. [REDACTED], <YOUR_KEY>).

Options:
  --json   Emit findings as a JSON array to stdout.
  --help   Show this help.

Exit codes:
  0  Clean
  1  Findings detected
  2  Error
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT="json"; shift ;;
    --help) show_help; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Must be run inside a git repo.
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "Not a git repository." >&2
  exit 2
}

# Well-known high-confidence credential formats.
KNOWN_PATTERNS='(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|sk_live_[0-9A-Za-z]{24,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

# Credential-named variable assignment heuristic.
# Matches: <cred-var>[suffix][:=] "value" where value is 12+ chars and
# starts with an alnum (so [REDACTED], <YOUR_KEY>, ${ENV_VAR} don't match).
CRED_VARS='(password|passwd|pwd|secret|apikey|api_key|api-key|privatekey|private_key|credential|access_key|accesskey|auth_token|accesstoken|sendgrid|smtppass|mailpass|hubspotkey|openaikey|deeplkey)'
ASSIGN_RE="${CRED_VARS}[a-zA-Z_-]*[[:space:]]*[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9+/=_.-]{12,}[\"']"

# Exclude the scanner itself (documents the pattern vocabulary) and this
# skill's docs (same reason). Callers can grep for everything else.
EXCLUDES=(
  ':!:.claude/skills/release/scripts/scan-secrets.sh'
  ':!:.claude/skills/release/SKILL.md'
)

FINDINGS="[]"

append_finding() {
  local file="$1" line="$2" pattern="$3" preview="$4"
  FINDINGS=$(jq --arg f "$file" --arg l "$line" --arg p "$pattern" --arg m "$preview" \
    '. + [{file: $f, line: ($l | tonumber), pattern: $p, match_preview: $m}]' <<< "$FINDINGS")
}

# Scan for well-known formats.
while IFS= read -r result; do
  [[ -z "$result" ]] && continue
  file=$(cut -d: -f1 <<< "$result")
  line=$(cut -d: -f2 <<< "$result")
  # Extract just the matched substring to generate a redacted preview.
  match=$(grep -oE "$KNOWN_PATTERNS" <<< "$result" | head -1)
  preview="${match:0:8}...(${#match} chars)"
  append_finding "$file" "$line" "Well-known credential format" "$preview"
done < <(git grep -nE "$KNOWN_PATTERNS" -- "${EXCLUDES[@]}" 2>/dev/null || true)

# Scan credential-named assignments.
while IFS= read -r result; do
  [[ -z "$result" ]] && continue
  file=$(cut -d: -f1 <<< "$result")
  line=$(cut -d: -f2 <<< "$result")
  content=$(cut -d: -f3- <<< "$result")
  # Pull the quoted value out of the line.
  value=$(grep -oE '["'"'"'][A-Za-z0-9+/=_.-]{12,}["'"'"']' <<< "$content" | head -1 | sed "s/^[\"']//; s/[\"']$//")
  [[ -z "$value" ]] && continue
  preview="${value:0:8}...(${#value} chars)"
  append_finding "$file" "$line" "Credential-named assignment" "$preview"
done < <(git grep -niE "$ASSIGN_RE" -- "${EXCLUDES[@]}" 2>/dev/null || true)

COUNT=$(jq 'length' <<< "$FINDINGS")

if [[ "$COUNT" -eq 0 ]]; then
  [[ "$OUTPUT" == "json" ]] && echo "[]"
  exit 0
fi

if [[ "$OUTPUT" == "json" ]]; then
  echo "$FINDINGS"
else
  echo "Potential credential leaks ($COUNT):" >&2
  jq -r '.[] | "  \(.file):\(.line)  [\(.pattern)]  \(.match_preview)"' <<< "$FINDINGS" >&2
fi

exit 1
