---
name: "aide-vision"
description: "Create or refine the project vision document for AI-driven development"
---

## User Input

```text
$ARGUMENTS
```

## Goal

Create or refine the project vision document, ensuring it covers all essential elements for AI-driven development planning.

## Execution Steps

### 1. Check Existing Vision

Check if `.specify/memory/vision.md` exists.

### 2. Gather Input

If creating new: ask about problem, target users, success metrics, scope.
If updating: present current vision and ask what to change.

### 3. Generate Vision Document

Create structured vision with: Problem Statement, Target Users, Success Metrics, Scope Boundaries, Key Assumptions.

### 4. Save

Write to `.specify/memory/vision.md` and report.
