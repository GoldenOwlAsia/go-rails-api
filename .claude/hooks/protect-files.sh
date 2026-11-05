#!/usr/bin/env bash
# PreToolUse hook for Read|Edit|Write|NotebookEdit.
#
# Keeps credential files out of the conversation and out of the diff.
# `.env.sample` stays allowed: it is the file to update when a new variable is
# introduced.
set -uo pipefail

. "$(dirname "$0")/lib.sh"
require_jq

payload=$(cat)
path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty') ||
  fail_closed "protect-files.sh could not parse its input, so the call was blocked."

[ -z "$path" ] && exit 0

if is_protected_path "$path"; then
  deny "Refusing to touch ${path##*/}: it holds real credentials. Update .env.sample for a new variable and tell the user what to set; use bin/rails credentials:edit for encrypted credentials."
fi

exit 0
