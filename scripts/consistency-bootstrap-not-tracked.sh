#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for f in CLAUDE.md .cursorrules; do
  if [ -f "$f" ] && git ls-files --error-unmatch "$f" 2>/dev/null; then
    echo "bootstrap-files-not-tracked: tracked forbidden file $f"
    exit 1
  fi
done

for dir in tasks/ prompts/ .claude/; do
  if git ls-files | grep -q "^${dir}"; then
    echo "bootstrap-files-not-tracked: tracked paths under ${dir}"
    git ls-files | grep "^${dir}" || true
    exit 1
  fi
done
