#!/usr/bin/env bash
set -euo pipefail

# release.sh — Deterministic release logic for the /release skill.
# Validates branch, detects changes, bumps versions, outputs structured JSON.

MARKETPLACE_JSON=".claude-plugin/marketplace.json"
DRY_RUN=false
BUMP_TYPE=""

# Temp file with cleanup trap
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# --- Output helpers ---

emit_error() {
  jq -n --arg error "$1" '{"status": "error", "error": $error}'
  exit 1
}

emit_no_changes() {
  jq -n '{"status": "no_changes", "message": "No changes detected since last release."}'
  exit 2
}

log() {
  echo "$@" >&2
}

# --- Core functions ---

show_help() {
  cat <<'HELP'
Usage: release.sh [OPTIONS] [major|minor|patch]

Detect changed plugins and marketplace changes, bump versions,
and output structured JSON for the /release skill.

Options:
  --help       Show this help message
  --dry-run    Calculate versions without modifying files

Bump type:
  major        Increment major version (X.0.0)
  minor        Increment minor version (0.X.0)
  patch        Increment patch version (0.0.X)
  (omit)       Auto-detect from conventional commit messages

Exit codes:
  0  Success (versions bumped, JSON output on stdout)
  1  Error (invalid state or arguments)
  2  No changes detected since last release
HELP
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help) show_help ;;
      --dry-run) DRY_RUN=true; shift ;;
      major|minor|patch) BUMP_TYPE="$1"; shift ;;
      *) emit_error "Invalid argument: $1. Use --help for usage." ;;
    esac
  done
}

validate_branch() {
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$BRANCH" == "main" ]]; then
    emit_error "Cannot release from main branch. Create a feature branch first."
  fi
  log "Branch: $BRANCH"
}

check_clean() {
  if [[ -n "$(git status --porcelain)" ]]; then
    emit_error "Uncommitted changes detected. Commit or stash them first."
  fi
}

find_baseline() {
  BASELINE=$(git log main..HEAD --format='%H' --grep='bump version' | head -1)
  if [[ -z "$BASELINE" ]]; then
    BASELINE=$(git merge-base HEAD main)
  fi
  log "Baseline: ${BASELINE:0:12}"
}

detect_changes() {
  # Get plugin directories from marketplace.json
  PLUGIN_DIRS=$(jq -r '.plugins[].source | ltrimstr("./")' "$MARKETPLACE_JSON" 2>/dev/null | tr '\n' '|' | sed 's/|$//')

  CHANGED_PLUGINS=""
  MARKETPLACE_CHANGED=false

  if [[ -n "$PLUGIN_DIRS" ]]; then
    CHANGED_PLUGINS=$(git diff "$BASELINE" --name-only | grep -E "^($PLUGIN_DIRS)/" | cut -d'/' -f1 | sort -u || true)
    local marketplace_files
    marketplace_files=$(git diff "$BASELINE" --name-only | grep -vE "^($PLUGIN_DIRS)/" | head -1 || true)
    if [[ -n "$marketplace_files" ]]; then
      MARKETPLACE_CHANGED=true
    fi
  else
    # No plugins defined — all changes are marketplace-level
    local any_changes
    any_changes=$(git diff "$BASELINE" --name-only | head -1 || true)
    if [[ -n "$any_changes" ]]; then
      MARKETPLACE_CHANGED=true
    fi
  fi

  if [[ -z "$CHANGED_PLUGINS" && "$MARKETPLACE_CHANGED" == "false" ]]; then
    emit_no_changes
  fi

  log "Changed plugins: ${CHANGED_PLUGINS:-none}"
  log "Marketplace changed: $MARKETPLACE_CHANGED"
}

determine_bump() {
  if [[ -n "$BUMP_TYPE" ]]; then
    log "Bump type (from arg): $BUMP_TYPE"
    return
  fi

  local commits
  commits=$(git log "$BASELINE"..HEAD --oneline)

  if echo "$commits" | grep -qE '(BREAKING CHANGE|!\s*:)'; then
    BUMP_TYPE="major"
  elif echo "$commits" | grep -qE '^[a-f0-9]+ feat'; then
    BUMP_TYPE="minor"
  else
    BUMP_TYPE="patch"
  fi

  log "Bump type (auto-detected): $BUMP_TYPE"
}

calc_version() {
  local current="$1" type="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"

  case "$type" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
  esac
}

bump_plugins() {
  PLUGINS_JSON="[]"

  if [[ -z "$CHANGED_PLUGINS" ]]; then
    return
  fi

  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue

    local plugin_json_file="$plugin/.claude-plugin/plugin.json"
    local old_ver
    old_ver=$(jq -r '.version' "$plugin_json_file")
    local new_ver
    new_ver=$(calc_version "$old_ver" "$BUMP_TYPE")

    log "  $plugin: $old_ver → $new_ver"

    if [[ "$DRY_RUN" == "false" ]]; then
      # Update plugin.json
      jq --arg v "$new_ver" '.version = $v' "$plugin_json_file" > "$TMPFILE" && mv "$TMPFILE" "$plugin_json_file"
      TMPFILE=$(mktemp)

      # Sync to marketplace.json
      jq --arg name "$plugin" --arg v "$new_ver" \
        '(.plugins[] | select(.name == $name)).version = $v' \
        "$MARKETPLACE_JSON" > "$TMPFILE" && mv "$TMPFILE" "$MARKETPLACE_JSON"
      TMPFILE=$(mktemp)
    fi

    # Accumulate plugin data for JSON output
    PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq \
      --arg name "$plugin" \
      --arg old "$old_ver" \
      --arg new "$new_ver" \
      --arg file "$plugin_json_file" \
      '. + [{"name": $name, "old_version": $old, "new_version": $new, "file": $file}]')

  done <<< "$CHANGED_PLUGINS"
}

bump_marketplace() {
  MKT_CHANGED_JSON="false"
  MKT_OLD_VERSION=""
  MKT_NEW_VERSION=""

  if [[ "$MARKETPLACE_CHANGED" == "false" ]]; then
    return
  fi

  MKT_CHANGED_JSON="true"
  MKT_OLD_VERSION=$(jq -r '.version' "$MARKETPLACE_JSON")
  MKT_NEW_VERSION=$(calc_version "$MKT_OLD_VERSION" "$BUMP_TYPE")

  log "  marketplace: $MKT_OLD_VERSION → $MKT_NEW_VERSION"

  if [[ "$DRY_RUN" == "false" ]]; then
    jq --arg v "$MKT_NEW_VERSION" '.version = $v' "$MARKETPLACE_JSON" > "$TMPFILE" && mv "$TMPFILE" "$MARKETPLACE_JSON"
    TMPFILE=$(mktemp)
  fi
}

verify_sync() {
  if [[ "$DRY_RUN" == "true" || -z "$CHANGED_PLUGINS" ]]; then
    return
  fi

  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue

    local plugin_ver marketplace_ver
    plugin_ver=$(jq -r '.version' "$plugin/.claude-plugin/plugin.json")
    marketplace_ver=$(jq -r --arg name "$plugin" '.plugins[] | select(.name == $name) | .version' "$MARKETPLACE_JSON")

    if [[ "$plugin_ver" != "$marketplace_ver" ]]; then
      emit_error "Version sync failed for $plugin: plugin.json=$plugin_ver, marketplace.json=$marketplace_ver"
    fi
  done <<< "$CHANGED_PLUGINS"

  log "Version sync verified."
}

build_commit_message() {
  local plugin_count
  plugin_count=$(echo "$PLUGINS_JSON" | jq 'length')

  local parts=""

  # Marketplace part
  if [[ "$MKT_CHANGED_JSON" == "true" ]]; then
    parts="marketplace v$MKT_NEW_VERSION"
  fi

  # Plugin parts
  if [[ "$plugin_count" -gt 0 ]]; then
    local plugin_parts
    plugin_parts=$(echo "$PLUGINS_JSON" | jq -r '.[] | "\(.name) v\(.new_version)"' | paste -sd ', ' -)
    if [[ -n "$parts" ]]; then
      parts="$parts, $plugin_parts"
    else
      parts="$plugin_parts"
    fi
  fi

  # Build message based on what changed
  if [[ "$plugin_count" -eq 1 && "$MKT_CHANGED_JSON" == "false" ]]; then
    local name ver
    name=$(echo "$PLUGINS_JSON" | jq -r '.[0].name')
    ver=$(echo "$PLUGINS_JSON" | jq -r '.[0].new_version')
    COMMIT_MESSAGE="chore($name): bump version to $ver"
  elif [[ "$plugin_count" -eq 0 && "$MKT_CHANGED_JSON" == "true" ]]; then
    COMMIT_MESSAGE="chore(marketplace): bump version to $MKT_NEW_VERSION"
  else
    COMMIT_MESSAGE="chore(release): bump versions — $parts"
  fi
}

build_files_modified() {
  FILES_MODIFIED_JSON="[]"

  # Add plugin files
  if [[ -n "$CHANGED_PLUGINS" ]]; then
    while IFS= read -r plugin; do
      [[ -z "$plugin" ]] && continue
      FILES_MODIFIED_JSON=$(echo "$FILES_MODIFIED_JSON" | jq --arg f "$plugin/.claude-plugin/plugin.json" '. + [$f]')
    done <<< "$CHANGED_PLUGINS"
  fi

  # Add marketplace.json (always modified if any version changed)
  FILES_MODIFIED_JSON=$(echo "$FILES_MODIFIED_JSON" | jq --arg f "$MARKETPLACE_JSON" '. + [$f]')
}

emit_output() {
  local commits_json
  commits_json=$(git log "$BASELINE"..HEAD --oneline | jq -R -s 'split("\n") | map(select(length > 0))')

  jq -n \
    --arg status "ok" \
    --arg branch "$BRANCH" \
    --arg baseline "$BASELINE" \
    --arg bump_type "$BUMP_TYPE" \
    --argjson plugins "$PLUGINS_JSON" \
    --argjson mkt_changed "$MKT_CHANGED_JSON" \
    --arg mkt_old "${MKT_OLD_VERSION:-}" \
    --arg mkt_new "${MKT_NEW_VERSION:-}" \
    --argjson files_modified "$FILES_MODIFIED_JSON" \
    --arg commit_message "$COMMIT_MESSAGE" \
    --argjson commits "$commits_json" \
    --argjson dry_run "$DRY_RUN" \
    '{
      status: $status,
      branch: $branch,
      baseline: $baseline,
      bump_type: $bump_type,
      plugins: $plugins,
      marketplace: {
        changed: $mkt_changed,
        old_version: $mkt_old,
        new_version: $mkt_new
      },
      files_modified: $files_modified,
      commit_message: $commit_message,
      commits_since_baseline: $commits,
      dry_run: $dry_run
    }'
}

# --- Main ---

main() {
  parse_args "$@"

  log "=== Release Script ==="
  validate_branch
  check_clean
  find_baseline

  log "Detecting changes..."
  detect_changes

  determine_bump

  log "Bumping versions..."
  bump_plugins
  bump_marketplace
  verify_sync

  build_commit_message
  build_files_modified
  emit_output
}

main "$@"
