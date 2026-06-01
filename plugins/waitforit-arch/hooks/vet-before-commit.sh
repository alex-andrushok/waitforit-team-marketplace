#!/usr/bin/env bash
# PreToolUse hook (Bash) — block `git commit` if the Go module doesn't build
# or vet cleanly. exit 2 cancels the command before it runs.
set -uo pipefail

cmd=$(cat | jq -r '.tool_input.command // empty')
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! out=$(go build ./... 2>&1); then
  printf 'vet-before-commit: go build failed — commit blocked\n%s\n' "$out" >&2
  exit 2
fi
if ! out=$(go vet ./... 2>&1); then
  printf 'vet-before-commit: go vet failed — commit blocked\n%s\n' "$out" >&2
  exit 2
fi
exit 0
