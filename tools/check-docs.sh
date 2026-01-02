#!/usr/bin/env bash
set -euo pipefail

# Check for absolute local paths and common secret patterns in markdown docs
if git grep -nE "/Users/|C:\\Users\\|BEGIN PRIVATE KEY|BEGIN RSA PRIVATE KEY|AKIA[0-9A-Z]{16}" -- "**/*.md"; then
  echo "Forbidden pattern found in docs; remove before commit." >&2
  exit 1
fi
exit 0
