#!/usr/bin/env bash
# PostToolUse hook — format the just-edited Go file with gofmt.
# Reads the tool payload (JSON) on stdin; no-op for non-Go files.
set -uo pipefail

file=$(cat | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
case "$file" in
  *.go) [ -f "$file" ] && gofmt -w "$file" ;;
esac
exit 0
