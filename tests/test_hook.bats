#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/promptup-hook.sh"

setup() {
  export PROMPTUP_DEFAULTS_PATH="$SCRIPT_DIR/../config/defaults.json"
  export TMPDIR="${BATS_TMPDIR:-/tmp}"
  export PROMPTUP_CONFIG_PATH="$TMPDIR/promptup_test_$$.json"
}

teardown() {
  rm -f "$PROMPTUP_CONFIG_PATH"
}

_make_stdin() {
  local prompt="$1"
  python3 -c "import json, sys; print(json.dumps({'session_id':'test','hook_event_name':'UserPromptSubmit','prompt':sys.argv[1],'cwd':'/tmp'}))" "$prompt"
}

@test "hook passes through when config missing (disabled)" {
  rm -f "$PROMPTUP_CONFIG_PATH"
  run bash -c '_make_stdin() { python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "$1"; }; _make_stdin "Please fix the auth bug in the login module" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through when enabled=false" {
  echo '{"enabled": false}' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "Please fix the auth bug in the login module" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through trivial prompts when enabled" {
  echo '{"enabled": true}' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "yes" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through slash commands when enabled" {
  echo '{"enabled": true}' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "/help" | '"$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook outputs JSON with additionalContext for qualifying prompts" {
  echo '{"enabled": true, "mode": "show-and-send", "level": "medium"}' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "Please fix the authentication bug in the login module" | '"$HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hookSpecificOutput' in d"
}

@test "hook outputs additionalContext containing rewriting instructions" {
  echo '{"enabled": true, "mode": "show-and-send", "level": "deep"}' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "fix the bug were users cant login" | '"$HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ctx = d['hookSpecificOutput']['additionalContext']
assert 'PromptUp' in ctx
assert 'deep' in ctx.lower() or 'Deep' in ctx
"
}

@test "hook handles malformed config gracefully" {
  echo '{broken json' > "$PROMPTUP_CONFIG_PATH"
  run bash -c 'python3 -c "import json,sys; print(json.dumps({\"session_id\":\"test\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":sys.argv[1],\"cwd\":\"/tmp\"}))" "Please fix the authentication bug in the login module" | '"$HOOK"' 2>/dev/null'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
