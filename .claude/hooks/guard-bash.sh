#!/usr/bin/env bash
# PreToolUse hook for Bash.
#
# Permission rules match on a command prefix, so `FOO=1 git push` escapes a
# `Bash(git push *)` deny rule. This hook splits the command on shell separators
# and judges each segment on its own, so an exemption in one segment
# (RAILS_ENV=test, --staged) cannot excuse another.
#
# It stops mistakes, it is not a security boundary: a regex cannot see through
# every shell indirection. When unsure it denies, so a quoted string that merely
# looks like a command can be refused. Add a case to test-guards.sh with any change.
set -uo pipefail

. "$(dirname "$0")/lib.sh"
require_jq

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty') ||
  fail_closed "guard-bash.sh could not parse its input, so the command was blocked."

[ -z "$cmd" ] && exit 0

squote="'"
space='[[:space:]]'
word='[^[:space:]]'

# One segment per line. `2>&1` is removed first so its `&` does not split.
segments() {
  printf '%s\n' "$1" | awk '{
    gsub(/[0-9]*>&[0-9-]+/, "")
    gsub(/&&|\|\||;|\||&|\(|\)|`|\{|\}/, "\n")
    print
  }'
}

# Peels what can sit in front of the real command: env assignments, wrappers such
# as `env` or `xargs -0`, `bash -c '...'`, `find ... -exec`.
strip_prefixes() {
  local s="$1" previous i=0
  while [ "$i" -lt 8 ]; do
    previous=$s
    s=$(printf '%s' "$s" | sed -E \
      -e "s/^(${space}|[\"${squote}])+//" \
      -e "s/^[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|${squote}[^${squote}]*${squote}|${word}*)${space}*//" \
      -e "s/^(${word}*\/)?(env|command|exec|builtin|nohup|time|sudo|nice|xargs)(${space}+-${word}*)*${space}+//" \
      -e "s/^(then|do|else|if|while|until|!|eval)${space}+//" \
      -e "s/^(${word}*\/)?(bash|sh|zsh|dash|ksh)(${space}+-[a-zA-Z]+)*${space}+-[a-zA-Z]*c${space}+//" \
      -e "s/^(${word}*\/)?find${space}.*-exec(dir)?${space}+//")
    [ "$s" = "$previous" ] && break
    i=$((i + 1))
  done
  printf '%s' "$s"
}

# A quoted argument becomes one placeholder word, so `git -C "a b" commit` parses.
collapse_quotes() {
  printf '%s' "$1" | sed -E \
    -e "s/\"[^\"]*\"/Q/g" \
    -e "s/${squote}[^${squote}]*${squote}/Q/g" \
    -e "s/[\"${squote}]//g"
}

check_production() {
  printf '%s' "$cmd" | grep -qE "(^|[^A-Za-z0-9_])(RAILS_ENV|RACK_ENV)=[\"${squote}]?prod" &&
    deny "Refusing to run a command against the production environment."
  printf '%s' "$cmd" | grep -qE "DATABASE_URL=${word}*prod" &&
    deny "Refusing to run a command against a production DATABASE_URL."
  return 0
}

check_rails() {
  local raw="$1"
  printf '%s' "$raw" | grep -qE "(^|${space}|/)(rails|rake)(${space}|$)" || return 0

  printf '%s' "$raw" | grep -qE "${space}(-e${space}*|--environment[=[:space:]]${space}*|(console|c|dbconsole)${space}+)prod" &&
    deny "Refusing to run a Rails command against the production environment."

  printf '%s' "$raw" | grep -qE "${space}credentials:(show|edit)(${space}|$)" &&
    deny "Refusing to run credentials:show or credentials:edit: they expose decrypted secrets. Ask the user to change credentials themselves."

  if printf '%s' "$raw" | grep -qE "${space}db:(drop|reset|purge|migrate:reset|schema:load|structure:load|setup|truncate_all|seed:replant)(:${word}*)?(${space}|$)"; then
    if printf '%s' "$raw" | grep -qE "DATABASE_URL=" ||
      ! printf '%s' "$raw" | grep -qE "(^|${space})RAILS_ENV=test(${space}|$)"; then
      deny "Refusing to run a destructive db task outside RAILS_ENV=test. Prefix this one command with RAILS_ENV=test if only the test database needs rebuilding; otherwise ask the user first."
    fi
  fi
}

check_git() {
  local sub arg
  set -f
  # shellcheck disable=SC2086 # word splitting is the point
  set -- $1
  set +f

  [ "${1:-}" != "" ] && [ "${1##*/}" = "git" ] || return 0
  shift

  while [ $# -gt 0 ]; do
    case "$1" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--config-env)
        shift
        [ $# -gt 0 ] && shift
        ;;
      -*) shift ;;
      *) break ;;
    esac
  done

  sub=${1:-}
  [ $# -gt 0 ] && shift

  case "$sub" in
    commit)
      deny "Refusing to run git commit. Committing is the user's decision: describe the change and let them commit it."
      ;;
    push)
      deny "Refusing to run git push. Publishing is the user's decision."
      ;;
    reset)
      for arg in "$@"; do
        [ "$arg" = "--hard" ] &&
          deny "Refusing to run git reset --hard: it discards uncommitted work. Stash instead, or ask the user."
      done
      ;;
    clean)
      for arg in "$@"; do
        case "$arg" in
          --force) deny "Refusing to run git clean -f: it deletes untracked files. Ask the user first." ;;
          --*) ;;
          -*f*) deny "Refusing to run git clean -f: it deletes untracked files. Ask the user first." ;;
        esac
      done
      ;;
    checkout)
      # Switching branches stays allowed. `--`, `.` and -f overwrite the working tree.
      for arg in "$@"; do
        case "$arg" in
          --|.|-f|--force) deny "Refusing to run this git checkout: it discards uncommitted changes. Stash first, or ask the user." ;;
        esac
      done
      ;;
    switch)
      for arg in "$@"; do
        case "$arg" in
          -f|--force|--discard-changes) deny "Refusing to run git switch with a discard flag: it throws away uncommitted changes. Stash first, or ask the user." ;;
        esac
      done
      ;;
    restore)
      # --staged alone only unstages; the content stays in the working tree.
      local staged=false worktree=false
      for arg in "$@"; do
        case "$arg" in
          --staged|-S) staged=true ;;
          --worktree|-W) worktree=true ;;
        esac
      done
      if [ "$staged" = false ] || [ "$worktree" = true ]; then
        deny "Refusing to run git restore on the working tree: it discards uncommitted changes. Stash first, or ask the user. (git restore --staged, which only unstages, is allowed.)"
      fi
      ;;
    stash)
      case "${1:-}" in
        drop|clear) deny "Refusing to run git stash $1: it deletes stashed work. Ask the user first." ;;
      esac
      ;;
  esac
}

secret_deny() {
  deny "Refusing to read, write or copy $1 from a shell command: it holds real credentials. Update .env.sample instead and tell the user which variable to set."
}

# Commands whose arguments are files they print, change or send elsewhere.
file_verbs='rm|mv|cp|tee|truncate|install|ln|shred|dd|sed|awk|gawk|perl|rsync|scp|curl|cat|less|more|head|tail|bat|nl|od|xxd|hexdump|strings|base64|grep|egrep|fgrep|rg|ag|diff|source|vi|vim|nano'

check_secret_args() {
  local tok
  printf '%s' "$1" | grep -qE "(^|${space}|/)(${file_verbs})(${space}|$)" || return 0
  set -f
  # shellcheck disable=SC2086 # word splitting is the point
  for tok in $1; do
    case "$tok" in -[!-]*) continue ;; esac
    tok=${tok##*=}
    tok=${tok#@}
    is_protected_path "$tok" && { set +f; secret_deny "$tok"; }
  done
  set +f
  return 0
}

# Redirect targets, read from the raw command because `&>` would otherwise split.
check_redirects() {
  local target
  while IFS= read -r target; do
    [ -n "$target" ] && is_protected_path "$target" && secret_deny "$target"
  done < <(printf '%s\n' "$cmd" |
    grep -oE "&?>>?\|?${space}*[^[:space:];&|<>()]+" |
    sed -E "s/^&?>>?\|?${space}*//")
  return 0
}

check_production
check_redirects

while IFS= read -r segment; do
  [ -z "$segment" ] && continue
  raw=$(printf '%s' "$segment" | tr -d "\"${squote}")
  stripped=$(strip_prefixes "$segment")

  check_rails "$raw"
  check_secret_args "$raw"
  check_git "$(collapse_quotes "$stripped")"
done < <(segments "$cmd")

exit 0
