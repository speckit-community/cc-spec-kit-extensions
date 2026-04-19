---
name: "verify-check"
description: "Run verification checks on spec, plan, and task artifacts for completeness and consistency"
---

## User Input

```text
$ARGUMENTS
```

## Goal

Run verification checks on the current feature's specification artifacts to ensure completeness, consistency, and quality.

## Execution Steps

### 1. Locate Feature Directory

Find the active feature directory under `specs/`. If `$ARGUMENTS` specifies a feature name, use that. Otherwise, find the most recently modified feature directory.

### 2. Run Verification Checks

Check the following in the feature directory:

**Required files:**
- `spec.md` — Feature specification
- `plan.md` — Implementation plan

**Optional files:**
- `tasks.md` — Task breakdown
- `data-model.md` — Data model
- `contracts/` — Interface contracts
- `research.md` — Research notes

**Content checks (spec.md):**
- Has "User Scenarios" or "User Story" section
- Has "Requirements" section
- Has "Success Criteria" section

**Content checks (plan.md):**
- Has "Summary" section
- Has "Technical Context" section
- Has "Project Structure" section

**Cross-references:**
- Tasks reference valid requirements from spec.md
- Plan references valid user stories from spec.md

### 3. Report Results

Print a verification report with pass/warn/fail for each check:

```
🔍 Spec Verification Report
Feature: {feature_name}

  {status} spec.md — {detail}
  {status} plan.md — {detail}
  {status} tasks.md — {detail}
  {status} Cross-references — {detail}

Result: {pass} passed, {warn} warnings, {fail} failed
```
