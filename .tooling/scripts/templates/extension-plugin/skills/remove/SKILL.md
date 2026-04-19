---
name: "remove"
description: "Remove the {EXT_NAME} extension from your project. Cleans up all files, hooks, and registry entries."
argument-hint: "Run without arguments to remove the extension"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

## Goal

Remove the **{EXT_NAME}** extension from the current project. This deletes runtime files, removes command skills, cleans hook entries, and removes the registry entry — all without affecting other installed extensions or the core workflow.

## Execution Steps

### Step 1: Check Preconditions

1. Check `.specify/` directory exists → if not: print "No spec-kit installation found." and **stop**.
2. Check `.specify/extensions/{EXT_ID}/` directory exists → if not: print "Extension '{EXT_NAME}' is not installed." and **stop**.

### Step 2: Confirm Removal

Display what will be removed:

```
🗑️  Remove extension "{EXT_NAME}"?
This will delete:
  - .specify/extensions/{EXT_ID}/ (runtime files)
  - .claude/skills/speckit-{EXT_ID}-*/ (command skills)
  - Hook entries in .specify/extensions.yml
  - Registry entry in .specify/extensions/.registry
```

### Step 3: Delete Runtime Files

**For bash (macOS / Linux):**

```bash
rm -rf .specify/extensions/{EXT_ID}
```

**For ps (Windows):**

```powershell
Remove-Item -Recurse -Force .specify/extensions/{EXT_ID} -ErrorAction SilentlyContinue
```

### Step 4: Delete Command Skills

**For bash (macOS / Linux):**

```bash
rm -rf .claude/skills/speckit-{EXT_ID}-*/
```

**For ps (Windows):**

```powershell
Remove-Item -Recurse -Force .claude/skills/speckit-{EXT_ID}-* -ErrorAction SilentlyContinue
```

### Step 5: Clean Hooks

Read `.specify/extensions.yml`. For every hook point under `hooks:`, remove all entries where `extension == "{EXT_ID}"`. Preserve all other entries unchanged. Write the updated file.

### Step 6: Update Registry

Read `.specify/extensions/.registry` (JSON). Remove the entry keyed by `"{EXT_ID}"` from the `extensions` object. Preserve all other entries unchanged. Write the updated file.

### Step 7: Report

```
✅ Extension "{EXT_NAME}" removed successfully.

Removed:
  - .specify/extensions/{EXT_ID}/ (runtime files)
  - .claude/skills/speckit-{EXT_ID}-*/ (command skills)
  - Hook entries from extensions.yml
  - Registry entry

Remaining extensions: {list remaining extensions from registry, or "none"}
```
