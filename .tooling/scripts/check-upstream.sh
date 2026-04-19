#!/usr/bin/env bash
# scripts/check-upstream.sh
#
# Check the spec-kit community catalog for new extension versions.
# Fetches the catalog from GitHub, compares upstream versions with
# the currently checked-in extension.yml versions.
#
# The catalog URL and list of tracked extensions are in extensions.json.
#
# Outputs:
#   JSON array of extensions that need regeneration (empty array if none).
#   Sets GitHub Actions output 'matrix' and 'has_updates' when running in CI.
#
# Usage:
#   ./scripts/check-upstream.sh
#
# Environment:
#   GITHUB_TOKEN    Optional. Used for authenticated GitHub API requests.
#   GITHUB_OUTPUT   Set automatically in GitHub Actions for setting outputs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$SCRIPT_DIR/../extensions.json"

if [ ! -f "$CONFIG" ]; then
  echo "Error: extensions.json not found at $CONFIG"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

# Read catalog URL and extension list from config
CATALOG_URL=$(python3 -c "
import json
with open('$CONFIG') as f:
    print(json.load(f)['catalog_url'])
")

TRACKED_EXTENSIONS=$(python3 -c "
import json
with open('$CONFIG') as f:
    for ext_id in json.load(f)['extensions']:
        print(ext_id)
")

echo "╔════════════════════════════════════════════════════╗"
echo "║  Spec Kit Extension Upstream Checker               ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Catalog: $CATALOG_URL"
echo ""

# Fetch the community catalog
echo "Fetching catalog..."
CATALOG=$(curl -sf "$CATALOG_URL" 2>/dev/null) || {
  echo "Error: Failed to fetch catalog from $CATALOG_URL"
  exit 1
}
echo "  ✓ Catalog fetched (updated: $(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('updated_at','unknown'))" <<< "$CATALOG"))"
echo ""

# Read current version from checked-in extension.yml
get_current_version() {
  local ext_id="$1"
  local ext_yml="$REPO_ROOT/plugins/$ext_id/assets/bash/.specify/extensions/$ext_id/extension.yml"

  if [ ! -f "$ext_yml" ]; then
    echo "0.0.0"
    return
  fi

  # Extract version from YAML — grep the line, strip quotes and whitespace
  grep -E '^\s+version:' "$ext_yml" | head -1 | sed 's/.*version:\s*//' | tr -d '"'"'" | tr -d ' '
}

# Compare semver versions: prints 'true' if v1 < v2
version_lt() {
  python3 -c "
v1 = [int(x) for x in '$1'.split('.')]
v2 = [int(x) for x in '$2'.split('.')]
print('true' if v1 < v2 else 'false')
"
}

UPDATES="[]"
HAS_UPDATES=false

while read -r ext_id; do
  [ -z "$ext_id" ] && continue

  # Look up extension in catalog — extract metadata fields
  EXT_INFO=$(python3 -c "
import json, sys
catalog = json.loads(sys.stdin.read())
ext = catalog.get('extensions', {}).get('$ext_id')
if ext:
    print(f\"{ext['version']}|{ext.get('repository','')}|{ext.get('download_url','')}\")
else:
    print('')
" <<< "$CATALOG")

  # Also extract catalog metadata for plugin.json
  CATALOG_META=$(python3 -c "
import json, sys
catalog = json.loads(sys.stdin.read())
ext = catalog.get('extensions', {}).get('$ext_id', {})
meta = {
    'description': ext.get('description', ''),
    'author': ext.get('author', ''),
    'license': ext.get('license', 'MIT'),
    'tags': ext.get('tags', [])
}
print(json.dumps(meta))
" <<< "$CATALOG")

  if [ -z "$EXT_INFO" ]; then
    echo "Checking: $ext_id"
    echo "  ⚠️  Not found in catalog — skipping"
    echo ""
    continue
  fi

  IFS='|' read -r catalog_version repository download_url <<< "$EXT_INFO"

  # Extract owner/repo from repository URL for GitHub API
  repo_slug=$(echo "$repository" | sed 's|https://github.com/||' | sed 's|/$||')

  echo "Checking: $ext_id ($repo_slug)"
  current=$(get_current_version "$ext_id")
  echo "  Current:  $current"
  echo "  Catalog:  $catalog_version"

  # Check the repo's latest release for the actual current version
  auth_header=""
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_header="Authorization: Bearer $GITHUB_TOKEN"
  fi

  release_json=$(curl -sf -H "Accept: application/vnd.github+json" \
    ${auth_header:+-H "$auth_header"} \
    "https://api.github.com/repos/$repo_slug/releases/latest" 2>/dev/null) || release_json=""

  if [ -n "$release_json" ]; then
    # Get version from release tag and download URL from release assets or tarball
    read -r upstream_version release_download_url <<< "$(python3 -c "
import json, sys, re
data = json.loads(sys.stdin.read())
tag = data.get('tag_name', '')
# Strip any prefix before the version number (v1.0.0, aide-v1.0.0, extensify-v1.0.0, etc.)
m = re.search(r'(\d+\.\d+\.\d+)', tag)
version = m.group(1) if m else tag
# Prefer zipball, fall back to first .zip asset
zip_url = data.get('zipball_url', '')
for asset in data.get('assets', []):
    if asset['name'].endswith('.zip'):
        zip_url = asset['browser_download_url']
        break
print(version, zip_url)
" <<< "$release_json")"

    echo "  Latest:   $upstream_version (from repo release)"

    # Use the release download URL if available, otherwise keep catalog URL
    if [ -n "$release_download_url" ]; then
      download_url="$release_download_url"
    fi
  else
    echo "  Latest:   (no releases found, using catalog version)"
    upstream_version="$catalog_version"
  fi

  is_newer=$(version_lt "$current" "$upstream_version")
  if [ "$is_newer" = "true" ]; then
    echo "  ⬆ Update available: $current → $upstream_version"
    UPDATES=$(python3 -c "
import json
updates = json.loads('$UPDATES')
catalog_meta = json.loads('$CATALOG_META')
updates.append({
    'id': '$ext_id',
    'current_version': '$current',
    'upstream_version': '$upstream_version',
    'repository': '$repository',
    'download_url': '$download_url',
    'catalog_description': catalog_meta['description'],
    'catalog_author': catalog_meta['author'],
    'catalog_license': catalog_meta['license'],
    'catalog_tags': catalog_meta['tags']
})
print(json.dumps(updates))
")
    HAS_UPDATES=true
  else
    echo "  ✓ Up to date"
  fi
  echo ""
done <<< "$TRACKED_EXTENSIONS"

echo "─────────────────────────────────────"

if [ "$HAS_UPDATES" = true ]; then
  update_count=$(python3 -c "import json; print(len(json.loads('$UPDATES')))")
  echo "Updates available: $update_count extension(s)"
  echo ""
  echo "Extensions to regenerate:"
  python3 -c "
import json
for u in json.loads('$UPDATES'):
    print(f\"  - {u['id']}: {u['current_version']} → {u['upstream_version']}\")
"
else
  echo "All extensions are up to date."
fi

# Set GitHub Actions outputs
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "has_updates=$HAS_UPDATES" >> "$GITHUB_OUTPUT"
  echo "matrix=$UPDATES" >> "$GITHUB_OUTPUT"
fi

echo ""
echo "$UPDATES"
