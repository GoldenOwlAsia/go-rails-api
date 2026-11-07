# Sourced by the PreToolUse guards. One copy of the path rules, so the Edit/Read
# channel and the shell channel cannot drift apart.

# A guard that cannot read its input must not allow everything. Exit 2 makes
# Claude Code block the tool call and show stderr.
fail_closed() {
  printf '%s\n' "$1" >&2
  exit 2
}

require_jq() {
  command -v jq >/dev/null 2>&1 ||
    fail_closed "jq is required by the .claude/hooks guards and was not found. Install it (brew install jq, apt-get install jq) so the safety checks can run."
}

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# True for files holding real credentials. Sample files carry no real values and
# are the place to document a new variable.
is_protected_path() {
  local p="$1" base
  p=${p//\"/}
  p=${p//\'/}
  base=${p##*/}

  case "$base" in
    .env.sample|.env.example|*.key.sample) return 1 ;;
  esac
  case "$base" in
    .env|.env.*|.env\*|master.key|*.pem|*.key) return 0 ;;
  esac
  case "$p" in
    config/credentials/*|*/config/credentials/*) return 0 ;;
  esac
  return 1
}
