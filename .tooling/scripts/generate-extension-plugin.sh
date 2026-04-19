#!/usr/bin/env bash
# scripts/generate-extension-plugin.sh
#
# Generate a complete, ready-to-publish extension plugin from any spec-kit extension.
#
# This is a BUILD-TIME tool — it requires Python 3, uv, and specify-cli.
# The output is a self-contained plugin directory within the extensions repo.
#
# Usage:
#   ./scripts/generate-extension-plugin.sh <extension-id> [options]
#
# Arguments:
#   extension-id    Required. The spec-kit extension identifier (e.g., "aide", "verify")
#
# Options:
#   --from <url>    Download URL for community extensions not in the core catalog
#   --output <dir>  Output directory (default: ./<extension-id>)
#   --version <ver> Override version string (default: from extension manifest)
#   --force         Regenerate even if assets already exist
#   --dry-run       Show what would be generated without writing files
#   --help          Show usage information
#
# Environment:
#   SPECKIT_LOCAL   If set, install specify-cli from this local path instead of GitHub
#
# Prerequisites:
#   - uv (https://docs.astral.sh/uv/)
#   - python3
#   - Network access (for specify-cli installation and template download)
#
# Examples:
#   ./scripts/generate-extension-plugin.sh verify
#   ./scripts/generate-extension-plugin.sh aide --from https://github.com/.../aide.zip
#   ./scripts/generate-extension-plugin.sh review --output /tmp/review-plugin --version 1.0.0
#   ./scripts/generate-extension-plugin.sh verify --dry-run
#
# Exit Codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Missing dependencies
#   3 - Extension not found
#   4 - Generation failure
#   5 - Validation failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates/extension-plugin"

# =========================================================================
# CLI Argument Parsing (T017)
# =========================================================================

EXT_ID=""
FROM_URL=""
OUTPUT_DIR=""
VERSION_OVERRIDE=""
DRY_RUN=false
FORCE=false

usage() {
  cat << 'EOF'
Usage: generate-extension-plugin.sh <extension-id> [options]

Arguments:
  extension-id          Required. The spec-kit extension identifier (e.g., "aide", "verify")

Options:
  --from <url>          Download URL for community extensions not in the core catalog
  --output <dir>        Output directory (default: ./<extension-id>)
  --version <ver>       Override version string (default: from extension manifest)
  --force               Regenerate even if assets already exist
  --dry-run             Show what would be generated without writing files
  --help                Show usage information

Environment:
  SPECKIT_LOCAL         If set, install specify-cli from this local path instead of GitHub

Exit Codes:
  0 - Success — plugin generated
  1 - Invalid arguments
  2 - Missing dependencies (uv, specify-cli)
  3 - Extension not found (invalid ID or unreachable URL)
  4 - Generation failure (specify init/add failed)
  5 - Validation failure (output structure incomplete)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      FROM_URL="${2:-}"
      if [ -z "$FROM_URL" ]; then
        echo "Error: --from requires a URL argument"
        exit 1
      fi
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      if [ -z "$OUTPUT_DIR" ]; then
        echo "Error: --output requires a directory argument"
        exit 1
      fi
      shift 2
      ;;
    --version)
      VERSION_OVERRIDE="${2:-}"
      if [ -z "$VERSION_OVERRIDE" ]; then
        echo "Error: --version requires a version argument"
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -z "$EXT_ID" ]; then
        EXT_ID="$1"
      else
        echo "Error: Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate extension ID
if [ -z "$EXT_ID" ]; then
  echo "Error: extension-id argument is required"
  usage
  exit 1
fi

if ! echo "$EXT_ID" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "Error: Invalid extension ID '$EXT_ID'. Must be lowercase kebab-case (e.g., 'aide', 'verify')"
  exit 1
fi

# Set default output directory
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$REPO_ROOT/plugins/$EXT_ID"
fi

echo "╔════════════════════════════════════════════════════╗"
echo "║  Spec Kit Extension Plugin Generator               ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Extension:  $EXT_ID"
echo "Output:     $OUTPUT_DIR"
[ -n "$FROM_URL" ] && echo "Source URL: $FROM_URL"
[ -n "$VERSION_OVERRIDE" ] && echo "Version:    $VERSION_OVERRIDE"
[ "$DRY_RUN" = true ] && echo "Mode:       DRY RUN"
echo ""

# =========================================================================
# Phase 1: Environment Setup (T018)
# =========================================================================

echo "── Phase 1: Environment Setup ──"

# Check for uv
if ! command -v uv &>/dev/null; then
  echo "Error: 'uv' is required. Install from https://docs.astral.sh/uv/"
  exit 2
fi
echo "  ✓ uv found: $(uv --version 2>/dev/null | head -1)"

# Install/update specify-cli
if [ -n "${SPECKIT_LOCAL:-}" ]; then
  echo "  Installing specify-cli from local: $SPECKIT_LOCAL"
  uv tool install --from "$SPECKIT_LOCAL" specify-cli --force --quiet 2>/dev/null || {
    echo "Error: Failed to install specify-cli from $SPECKIT_LOCAL"
    exit 2
  }
else
  echo "  Installing/updating specify-cli..."
  uv tool install specify-cli --quiet 2>/dev/null || uv tool install specify-cli --force --quiet 2>/dev/null || {
    echo "Error: Failed to install specify-cli"
    exit 2
  }
fi

# Verify specify works
if ! specify version &>/dev/null; then
  echo "Error: 'specify' command not functional after installation"
  exit 2
fi
echo "  ✓ specify-cli ready"
echo ""

# =========================================================================
# Phase 2: Per-Platform Asset Generation (T019)
# =========================================================================

echo "── Phase 2: Asset Generation ──"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would generate assets for platforms: bash, ps"
  echo "  [DRY RUN] Would run specify init + extension add for each platform"
  echo ""
else
  for variant_pair in "bash:sh" "ps:ps"; do
    variant="${variant_pair%%:*}"
    script_flag="${variant_pair##*:}"

    local_asset_dir="$OUTPUT_DIR/assets/$variant"

    # If pre-existing assets exist and have extension.yml, skip unless --force
    if [ -f "$local_asset_dir/.specify/extensions/$EXT_ID/extension.yml" ] && [ "$FORCE" != true ]; then
      echo "  ✓ $variant assets already present — skipping generation (use --force to regenerate)"
      continue
    fi

    # If --force, clean the extension assets directory first
    if [ "$FORCE" = true ] && [ -d "$local_asset_dir/.specify/extensions/$EXT_ID" ]; then
      echo "  Cleaning existing $variant assets (--force)"
      rm -rf "$local_asset_dir/.specify/extensions/$EXT_ID"
      rm -rf "$local_asset_dir/.claude/skills"/speckit-${EXT_ID}-*
    fi

    echo "  Generating assets for platform: $variant (script: $script_flag)"

    # Create temporary workspace
    TEMP_WORKSPACE=$(mktemp -d)
    trap "rm -rf '$TEMP_WORKSPACE'" EXIT

    # Run specify init
    INIT_OK=false
    (
      cd "$TEMP_WORKSPACE"
      specify init . --ai claude --here --force --no-git --script "$script_flag" 2>/dev/null
    ) && INIT_OK=true || {
      echo "  ⚠️  specify init failed for $variant"
    }

    # Try to add the extension
    if command -v specify &>/dev/null; then
      (
        cd "$TEMP_WORKSPACE"
        if [ -n "$FROM_URL" ]; then
          specify extension add "$EXT_ID" --from "$FROM_URL" 2>/dev/null || true
        else
          specify extension add "$EXT_ID" 2>/dev/null || true
        fi
      ) || true
    fi

    # Extract extension-specific files
    mkdir -p "$local_asset_dir/.specify/extensions" "$local_asset_dir/.claude/skills"

    # If the specify tool created extension files, use them
    if [ -d "$TEMP_WORKSPACE/.specify/extensions/$EXT_ID" ]; then
      cp -R "$TEMP_WORKSPACE/.specify/extensions/$EXT_ID" \
            "$local_asset_dir/.specify/extensions/$EXT_ID"
    fi

    # Copy command skills
    for skill_dir in "$TEMP_WORKSPACE/.claude/skills"/speckit-${EXT_ID}-*; do
      if [ -d "$skill_dir" ]; then
        cp -R "$skill_dir" "$local_asset_dir/.claude/skills/"
      fi
    done

    rm -rf "$TEMP_WORKSPACE"
    trap - EXIT

    # Verify we got something
    if [ -d "$local_asset_dir/.specify/extensions/$EXT_ID" ]; then
      echo "  ✓ $variant assets generated"
    else
      echo "  ⚠️  No extension assets generated for $variant via specify-cli"
      echo "  Checking for pre-existing assets..."

      # Fallback: check if assets already exist in the repo
      if [ -d "$OUTPUT_DIR/assets/$variant/.specify/extensions/$EXT_ID" ]; then
        echo "  ✓ Using pre-existing $variant assets"
      else
        echo "  ⚠️  No assets for $variant — plugin may be incomplete"
      fi
    fi
  done
  echo ""
fi

# =========================================================================
# Phase 3: Plugin Scaffolding (T020)
# =========================================================================

echo "── Phase 3: Plugin Scaffolding ──"

# Read extension metadata from the generated extension.yml
EXT_YML=""
for variant in bash ps; do
  candidate="$OUTPUT_DIR/assets/$variant/.specify/extensions/$EXT_ID/extension.yml"
  if [ -f "$candidate" ]; then
    EXT_YML="$candidate"
    break
  fi
done

if [ -z "$EXT_YML" ] || [ ! -f "$EXT_YML" ]; then
  echo "Warning: No extension.yml found in generated assets. Using defaults."
  EXT_NAME="$(python3 -c "print('$EXT_ID'.capitalize())" 2>/dev/null || echo "$EXT_ID") Extension"
  EXT_VERSION="${VERSION_OVERRIDE:-0.1.0}"
  EXT_DESCRIPTION="$EXT_ID extension for Spec Kit"
  EXT_AUTHOR="spec-kit-community"
  EXT_LICENSE="MIT"
  COMMAND_LIST=""
  HOOK_LIST=""
else
  # Extract metadata from extension.yml
  EXT_NAME=$(grep -A1 "^  name:" "$EXT_YML" | head -1 | sed 's/.*name:[[:space:]]*//' | tr -d '"')
  EXT_VERSION=$(grep -A1 "^  version:" "$EXT_YML" | head -1 | sed 's/.*version:[[:space:]]*//' | tr -d '"')
  EXT_DESCRIPTION=$(grep -A1 "^  description:" "$EXT_YML" | head -1 | sed 's/.*description:[[:space:]]*//' | tr -d '"')
  EXT_AUTHOR=$(grep -A1 "^  author:" "$EXT_YML" | head -1 | sed 's/.*author:[[:space:]]*//' | tr -d '"')
  EXT_LICENSE=$(grep -A1 "^  license:" "$EXT_YML" | head -1 | sed 's/.*license:[[:space:]]*//' | tr -d '"')

  # Extract commands
  COMMAND_LIST=$(python3 -c "
import re
with open('$EXT_YML') as f:
    content = f.read()
names = re.findall(r'- name:\s+(speckit\.\S+)', content)
for n in names:
    print(n)
" 2>/dev/null || echo "")

  # Extract hooks
  HOOK_LIST=$(python3 -c "
import re
with open('$EXT_YML') as f:
    content = f.read()
hooks = re.findall(r'^  ((?:before|after)_\w+):', content, re.MULTILINE)
for h in hooks:
    print(h)
" 2>/dev/null || echo "")
fi

# Apply version override if specified
if [ -n "$VERSION_OVERRIDE" ]; then
  EXT_VERSION="$VERSION_OVERRIDE"
fi

PLUGIN_VERSION="${EXT_VERSION}"

echo "  Extension: $EXT_NAME (v$EXT_VERSION)"
echo "  Author:    $EXT_AUTHOR"
echo "  License:   $EXT_LICENSE"

# Format command list for templates
COMMAND_LIST_FORMATTED=""
if [ -n "$COMMAND_LIST" ]; then
  while IFS= read -r cmd; do
    COMMAND_LIST_FORMATTED="${COMMAND_LIST_FORMATTED}\n- \`$cmd\`"
  done <<< "$COMMAND_LIST"
fi

HOOK_LIST_FORMATTED=""
if [ -n "$HOOK_LIST" ]; then
  while IFS= read -r hook; do
    HOOK_LIST_FORMATTED="${HOOK_LIST_FORMATTED}\n- \`$hook\`"
  done <<< "$HOOK_LIST"
fi

# JSON-formatted command list for registry
COMMAND_JSON=$(python3 -c "
cmds = '''$COMMAND_LIST'''.strip().split('\n')
cmds = [c.strip() for c in cmds if c.strip()]
print(', '.join('\"' + c + '\"' for c in cmds))
" 2>/dev/null || echo "")

# Template substitution function
substitute_template() {
  local input="$1"
  local output="$2"

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would generate: $output"
    return
  fi

  mkdir -p "$(dirname "$output")"
  sed \
    -e "s|{EXT_ID}|$EXT_ID|g" \
    -e "s|{EXT_NAME}|$EXT_NAME|g" \
    -e "s|{EXT_VERSION}|$EXT_VERSION|g" \
    -e "s|{EXT_DESCRIPTION}|$EXT_DESCRIPTION|g" \
    -e "s|{EXT_AUTHOR}|$EXT_AUTHOR|g" \
    -e "s|{EXT_LICENSE}|$EXT_LICENSE|g" \
    -e "s|{PLUGIN_VERSION}|$PLUGIN_VERSION|g" \
    "$input" > "$output"

  # Replace multi-line placeholders with Python for safety
  if grep -q "{COMMAND_LIST}" "$output" 2>/dev/null; then
    python3 -c "
with open('$output') as f:
    content = f.read()
content = content.replace('{COMMAND_LIST}', '''$COMMAND_LIST_FORMATTED'''.strip())
with open('$output', 'w') as f:
    f.write(content)
" 2>/dev/null || true
  fi

  if grep -q "{HOOK_LIST}" "$output" 2>/dev/null; then
    python3 -c "
with open('$output') as f:
    content = f.read()
content = content.replace('{HOOK_LIST}', '''$HOOK_LIST_FORMATTED'''.strip())
with open('$output', 'w') as f:
    f.write(content)
" 2>/dev/null || true
  fi
}

# Generate plugin files from templates
substitute_template "$TEMPLATE_DIR/summon.yaml" "$OUTPUT_DIR/summon.yaml"
substitute_template "$TEMPLATE_DIR/.claude-plugin/plugin.json" "$OUTPUT_DIR/.claude-plugin/plugin.json"
substitute_template "$TEMPLATE_DIR/skills/install/SKILL.md" "$OUTPUT_DIR/skills/install/SKILL.md"
substitute_template "$TEMPLATE_DIR/skills/remove/SKILL.md" "$OUTPUT_DIR/skills/remove/SKILL.md"
substitute_template "$TEMPLATE_DIR/README.md" "$OUTPUT_DIR/README.md"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "── Dry Run Complete ──"
  echo "Would generate plugin at: $OUTPUT_DIR"
  exit 0
fi

echo "  ✓ Plugin scaffolding complete"
echo ""

# =========================================================================
# Phase 4: Validation (T021)
# =========================================================================

echo "── Phase 4: Validation ──"

VALIDATION_ERRORS=0

# Check required files
for required_file in \
  "summon.yaml" \
  "README.md" \
  "skills/install/SKILL.md" \
  "skills/remove/SKILL.md" \
  ".claude-plugin/plugin.json"; do
  if [ -f "$OUTPUT_DIR/$required_file" ]; then
    echo "  ✓ $required_file"
  else
    echo "  ✗ $required_file — MISSING"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  fi
done

# Check platform variants
for variant in bash ps; do
  ext_dir="$OUTPUT_DIR/assets/$variant/.specify/extensions/$EXT_ID"
  if [ -d "$ext_dir" ]; then
    if [ -f "$ext_dir/extension.yml" ]; then
      echo "  ✓ assets/$variant — extension.yml present"
    else
      echo "  ✗ assets/$variant — extension.yml MISSING"
      VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
  else
    echo "  ⚠️  assets/$variant — extension directory missing (plugin may be incomplete)"
  fi

  skill_dir="$OUTPUT_DIR/assets/$variant/.claude/skills"
  skill_count=$(find "$skill_dir" -maxdepth 1 -name "speckit-${EXT_ID}-*" -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$skill_count" -gt 0 ]; then
    echo "  ✓ assets/$variant — $skill_count command skill(s) found"
  else
    echo "  ⚠️  assets/$variant — no command skills found"
  fi
done

# Verify summon.yaml only declares install/remove
if grep -q "speckit-ext-$EXT_ID" "$OUTPUT_DIR/summon.yaml" 2>/dev/null; then
  echo "  ✓ summon.yaml — correct plugin name"
else
  echo "  ✗ summon.yaml — incorrect plugin name"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

echo ""

if [ "$VALIDATION_ERRORS" -gt 0 ]; then
  echo "❌ Validation failed with $VALIDATION_ERRORS error(s)"
  exit 5
fi

# Report output structure
echo "╔════════════════════════════════════════════════════╗"
echo "║  ✅ Extension plugin generated successfully!        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Output: $OUTPUT_DIR"
echo ""
echo "Structure:"
find "$OUTPUT_DIR" -type f | sort | sed "s|$OUTPUT_DIR/|  |"
echo ""
echo "Next steps:"
echo "  1. Review generated files"
echo "  2. Test: install the plugin and run /speckit-ext-$EXT_ID:install"
echo "  3. Commit: git add $EXT_ID && git commit"
