#!/usr/bin/env bash
# verify-check.sh — Run verification checks on spec artifacts
set -euo pipefail

SPEC_DIR="${1:-.}"
FEATURE_DIR=""

# Find active feature directory
if [ -d "$SPEC_DIR/specs" ]; then
  FEATURE_DIR=$(find "$SPEC_DIR/specs" -maxdepth 1 -mindepth 1 -type d | head -1)
fi

if [ -z "$FEATURE_DIR" ]; then
  echo "No feature directory found under specs/"
  exit 1
fi

FEATURE_NAME=$(basename "$FEATURE_DIR")
PASS=0
WARN=0
FAIL=0

echo "🔍 Spec Verification Report"
echo "Feature: $FEATURE_NAME"
echo ""

# Check spec.md
if [ -f "$FEATURE_DIR/spec.md" ]; then
  echo "  ✅ spec.md — Found"
  PASS=$((PASS + 1))
else
  echo "  ❌ spec.md — Missing"
  FAIL=$((FAIL + 1))
fi

# Check plan.md
if [ -f "$FEATURE_DIR/plan.md" ]; then
  echo "  ✅ plan.md — Found"
  PASS=$((PASS + 1))
else
  echo "  ❌ plan.md — Missing"
  FAIL=$((FAIL + 1))
fi

# Check tasks.md
if [ -f "$FEATURE_DIR/tasks.md" ]; then
  echo "  ✅ tasks.md — Found"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  tasks.md — Missing (optional at this stage)"
  WARN=$((WARN + 1))
fi

echo ""
echo "Result: $PASS passed, $WARN warnings, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
