---
name: "install"
description: "Install the AIDE Workflow extension into your project. Copies runtime files, registers hooks, and makes commands available."
argument-hint: "Run without arguments to install, or use --force to overwrite"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

## Goal

Install the **AIDE Workflow** extension into the current project. This copies pre-generated runtime files, registers lifecycle hooks, updates the extension registry, and makes the extension's commands available as skills.

## Execution Steps

### Step 1: Security Warning

Display this warning before proceeding:

```
⚠️  EXTENSION TRUST WARNING
Extensions are not verified by the core spec-kit team.
Only install extensions you trust.
Proceeding will copy files into your project.
```

### Step 2: Check Preconditions

Verify the core spec-kit plugin is initialized:

1. Check `.specify/` directory exists → if not: print "Core spec-kit plugin must be initialized first. Run /speckit:init" and **stop**.
2. Check `.specify/extensions.yml` exists → if not: print "Hook registration file missing. Re-initialize with /speckit:init" and **stop**.
3. Check `.specify/extensions/.registry` exists → if not: print "Extension registry missing. Re-initialize with /speckit:init" and **stop**.

### Step 3: Platform Detection

Determine the correct asset variant to install:

```bash
PLATFORM_CHECK=$(uname -s 2>/dev/null || echo "Windows")
```

- If the output contains `MINGW`, `MSYS`, `CYGWIN`, or `Windows` → set `PLATFORM=ps`
- Otherwise (Darwin, Linux, etc.) → set `PLATFORM=bash`

### Step 4: Conflict Detection

Read `.specify/extensions/.registry` and collect all `registered_commands` values across all installed extensions. Compare against this extension's commands:

**Commands provided by this extension:**
- `speckit.aide.vision`
- `speckit.aide.requirements`

If any command name conflicts with an already-installed extension:

```
⚠️  Command conflict detected:
  - {conflicting_command} conflicts with extension "{other_ext}"
Continue anyway? (y/n)
```

If the user declines, **stop without changes**.

### Step 5: Copy Runtime Files

Copy the extension's pre-generated files into the project:

**For bash (macOS / Linux):**

```bash
# Copy extension runtime files
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/bash/.specify/extensions/aide" \
      .specify/extensions/aide

# Copy command skills
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/bash/.claude/skills"/speckit-aide-* \
      .claude/skills/
```

**For ps (Windows):**

```powershell
Copy-Item -Recurse -Force "${CLAUDE_PLUGIN_ROOT}/assets/ps/.specify/extensions/aide" .specify/extensions/aide
Copy-Item -Recurse -Force "${CLAUDE_PLUGIN_ROOT}/assets/ps/.claude/skills/speckit-aide-*" .claude/skills/
```

### Step 6: Set Script Permissions (bash only)

If `PLATFORM=bash`, make shell scripts executable:

```bash
find .specify/extensions/aide -name '*.sh' -exec chmod +x {} +
```

Skip on Windows — PowerShell scripts do not need execute permission.

### Step 7: Merge Hooks

Read `.specify/extensions.yml`. For each hook defined by this extension, check if an entry with the same `extension` + `command` already exists at that hook point.

**Hooks to register:**
- `before_specify`
- `before_plan`

For each hook:
- If **not present** at the hook point → append the entry with fields: `extension: aide`, `command`, `enabled: true`, `optional`, `prompt`, `description`, `condition: null`
- If **already present** → skip (idempotency — no duplicate entries)

Write the updated `.specify/extensions.yml`.

### Step 8: Update Registry

Read `.specify/extensions/.registry` (JSON). Add or update the entry for this extension:

```json
{
  "aide": {
    "version": "1.1.0",
    "source": "local",
    "manifest_hash": "sha256:{computed from extension.yml}",
    "enabled": true,
    "priority": 10,
    "registered_commands": {
      "claude": [- `speckit.aide.vision`
- `speckit.aide.requirements`]
    },
    "registered_skills": [],
    "installed_at": "{ISO 8601 timestamp}"
  }
}
```

Compute `manifest_hash` by running:
```bash
shasum -a 256 .specify/extensions/aide/extension.yml | cut -d' ' -f1
```

Write the updated `.specify/extensions/.registry`.

### Step 9: Report

Print a summary of the installation:

```
✅ Extension "AIDE Workflow" installed successfully!

Installed commands:
- `speckit.aide.vision`
- `speckit.aide.requirements`

Registered hooks:
- `before_specify`
- `before_plan`

⚠️  Restart your session to pick up the new skills.
```
