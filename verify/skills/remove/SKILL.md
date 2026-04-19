---
name: "remove"
description: "Remove the Spec Verification extension from your project. Cleans up all files, hooks, and registry entries."
argument-hint: "Run without arguments to remove the extension"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

## Goal

Remove the **Spec Verification** extension from the current project. This deletes runtime files, removes command skills, cleans hook entries, and removes the registry entry — all without affecting other installed extensions or the core workflow.

## Execution Steps

### Step 1: Check Preconditions

1. Check `.specify/` directory exists → if not: print "No spec-kit installation found." and **stop**.
2. Check `.specify/extensions/verify/` directory exists → if not: print "Extension 'Spec Verification' is not installed." and **stop**.

### Step 2: Confirm Removal

Display what will be removed:

```
🗑️  Remove extension "Spec Verification"?
This will delete:
  - .specify/extensions/verify/ (runtime files)
  - .claude/skills/speckit-verify-*/ (command skills)
  - Hook entries in .specify/extensions.yml
  - Registry entry in .specify/extensions/.registry
```

### Step 3: Delete Runtime Files

**For bash (macOS / Linux):**

```bash
rm -rf .specify/extensions/verify
```

**For ps (Windows):**

```powershell
Remove-Item -Recurse -Force .specify/extensions/verify -ErrorAction SilentlyContinue
```

### Step 4: Delete Command Skills

**For bash (macOS / Linux):**

```bash
rm -rf .claude/skills/speckit-verify-*/
```

**For ps (Windows):**

```powershell
Remove-Item -Recurse -Force .claude/skills/speckit-verify-* -ErrorAction SilentlyContinue
```

### Step 5: Clean Hooks

Read `.specify/extensions.yml`. For every hook point under `hooks:`, remove all entries where `extension == "verify"`. Preserve all other entries unchanged. Write the updated file.

### Step 6: Update Registry

Read `.specify/extensions/.registry` (JSON). Remove the entry keyed by `"verify"` from the `extensions` object. Preserve all other entries unchanged. Write the updated file.

### Step 7: Report

```
✅ Extension "Spec Verification" removed successfully.

Removed:
  - .specify/extensions/verify/ (runtime files)
  - .claude/skills/speckit-verify-*/ (command skills)
  - Hook entries from extensions.yml
  - Registry entry

Remaining extensions: {list remaining extensions from registry, or "none"}
```
