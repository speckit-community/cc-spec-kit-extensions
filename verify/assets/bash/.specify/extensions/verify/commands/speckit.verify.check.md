# speckit.verify.check

Run verification checks on spec-kit artifacts to ensure completeness, consistency, and quality.

## Usage

Invoke this command to validate your current feature's specification artifacts.

## Behavior

1. Locate the active feature directory under `specs/`
2. Check that required files exist: `spec.md`, `plan.md`, `tasks.md`
3. Validate spec.md has required sections (User Stories, Requirements, Success Criteria)
4. Validate plan.md has required sections (Summary, Technical Context, Project Structure)
5. Validate tasks.md has at least one task defined
6. Check for cross-reference consistency between spec → plan → tasks
7. Report findings with pass/warn/fail status for each check

## Output

```
🔍 Spec Verification Report
Feature: {feature_name}

  ✅ spec.md — All required sections present
  ✅ plan.md — All required sections present
  ⚠️  tasks.md — 2 tasks reference undefined requirements
  ✅ Cross-references — Consistent

Result: 3 passed, 1 warning, 0 failed
```
