#!/usr/bin/env bash
# Stop hook.
#
# Lints the files that changed and asks Claude to fix what it finds. It blocks at
# most once per stop: Claude Code sets stop_hook_active on the retry, and a failure
# Claude cannot fix must not trap the turn in a loop. A broken environment (missing
# gems, no database.yml) is reported, never blocked on. Does NOT run RSpec: targeted
# specs are the model's job.
set -uo pipefail

payload=$(cat)

warn() {
  jq -nc --arg message "verify-changes: $1" '{systemMessage: $message}'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  echo "verify-changes: jq not found, lint check skipped." >&2
  exit 0
fi

[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

ruby_files=()
autoloaded_changed=false
while IFS= read -r -d '' file; do
  # Deleted paths are still listed by git status; RuboCop must not be handed them.
  [ -f "$file" ] || continue
  case "$file" in
    *.rb|*.rake|*.ru|Gemfile|Rakefile) ruby_files+=("$file") ;;
    *) continue ;;
  esac
  case "$file" in
    app/*.rb|lib/*.rb) autoloaded_changed=true ;;
  esac
done < <(git diff --name-only -z --diff-filter=d HEAD 2>/dev/null; git ls-files --others --exclude-standard -z 2>/dev/null)

[ "${#ruby_files[@]}" -eq 0 ] && exit 0

bundle check >/dev/null 2>&1 || warn "gems are not installed for this Ruby, RuboCop and zeitwerk:check were skipped."

problems=""

out=$(bundle exec rubocop --force-exclusion --no-color "${ruby_files[@]}" 2>&1)
status=$?
case "$status" in
  0) ;;
  1) problems="RuboCop failed:
$(printf '%s' "$out" | tail -30)

" ;;
  *) warn "RuboCop could not run (exit $status): $(printf '%s' "$out" | tail -3)" ;;
esac

# Structural Ruby changes can break autoloading without any linter noticing.
if [ "$autoloaded_changed" = true ]; then
  if ! out=$(RAILS_ENV=test bin/rails zeitwerk:check 2>&1); then
    if printf '%s' "$out" | grep -qE 'expected file|Zeitwerk::'; then
      problems="${problems}zeitwerk:check failed:
$(printf '%s' "$out" | tail -20)

"
    else
      [ -z "$problems" ] && warn "zeitwerk:check could not run: $(printf '%s' "$out" | tail -3)"
    fi
  fi
fi

if [ -n "$problems" ]; then
  reason="${problems}Fix what your change introduced. If a failure is in a file you did not touch or cannot be fixed from here, say so and stop instead of editing unrelated code; this check will not block again this turn."
  jq -nc --arg reason "$reason" '{decision: "block", reason: $reason}'
fi

exit 0
