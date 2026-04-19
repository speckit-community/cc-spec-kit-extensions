---
name: "aide-requirements"
description: "Generate structured requirements from vision and user input"
---

## User Input

```text
$ARGUMENTS
```

## Goal

Generate structured, prioritized requirements for the current feature.

## Execution Steps

### 1. Gather Context

Read vision and spec if available.

### 2. Analyze and Generate

Generate categorized requirements: Functional (FR), Non-Functional (NFR), Constraints (CON).

### 3. Prioritize (MoSCoW)

Must Have, Should Have, Could Have, Won't Have.

### 4. Save

Write to `specs/{feature}/requirements.md` and report.
