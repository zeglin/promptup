# PromptUp Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that improves user prompts via a `/pp` skill and an always-on `UserPromptSubmit` hook using context injection.

**Architecture:** Plugin with two skills (markdown prompt files in skill directories) and one shell hook script. The hook reads `~/.claude/promptup.json` for config, applies smart-skip logic in bash, and injects rewriting instructions as `additionalContext` JSON for qualifying prompts. Claude itself performs the rewriting — no external API calls needed.

**Tech Stack:** Bash (hook script), Markdown/YAML (skills), JSON (config/manifest), bats-core (shell testing)

**Spec:** `docs/superpowers/specs/2026-03-13-promptup-design.md`

---

## Key Architecture Decisions

1. **Context injection, not prompt replacement** — `UserPromptSubmit` hooks cannot replace prompts. The hook outputs JSON with `additionalContext` containing rewriting instructions. Claude sees both the original prompt and the instructions, rewrites inline, and responds.
2. **No external API calls** — Claude itself does the rewriting using the session model. No `ANTHROPIC_API_KEY` needed, no latency overhead, no cost beyond the session.
3. **Skills are directories** — Each skill is a directory with a `SKILL.md` file (e.g., `skills/pp/SKILL.md`), not a flat `.md` file.
4. **Hook stdin is JSON** — The hook receives `{"prompt": "...", "session_id": "...", ...}` and must parse it.
5. **Paths use `${CLAUDE_PLUGIN_ROOT}`** — Hook scripts use this variable for portability after plugin installation.

---

## File Map

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin manifest — declares skills, hooks, metadata |
| `config/defaults.json` | Default configuration values (source of truth) |
| `hooks/hooks.json` | Hook declarations for Claude Code |
| `hooks/promptup-hook.sh` | Smart-skip logic, config reading, context injection output |
| `hooks/lib/config.sh` | Config reading/validation functions (sourced by hook) |
| `hooks/lib/skip.sh` | Smart-skip detection functions (sourced by hook) |
| `skills/pp/SKILL.md` | `/pp` skill — manual prompt rewriting |
| `skills/pp-config/SKILL.md` | `/pp-config` skill — config management |
| `tests/test_config.bats` | Tests for config reading/validation |
| `tests/test_skip.bats` | Tests for smart-skip logic |
| `tests/test_hook.bats` | Integration tests for the full hook |
| `tests/fixtures/` | Test config files (valid, invalid, missing fields) |
| `LICENSE` | MIT license |
| `README.md` | Installation, usage, configuration docs |

---

## Chunk 1: Foundation (scaffold + config + smart-skip)

### Task 1: Plugin Scaffold

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `config/defaults.json`
- Create: `hooks/hooks.json`
- Create: `LICENSE`

- [ ] **Step 1: Create plugin manifest**

`.claude-plugin/plugin.json`:
```json
{
  "name": "promptup",
  "version": "1.0.0",
  "description": "Automatically improves your prompts — better language, clearer instructions, smarter structure",
  "author": {
    "name": "Voy Zeglin",
    "url": "https://github.com/zeglin"
  },
  "license": "MIT",
  "homepage": "https://github.com/zeglin/promptup",
  "repository": "https://github.com/zeglin/promptup",
  "keywords": ["prompt", "rewriting", "language", "productivity"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
```

- [ ] **Step 2: Create hooks.json**

`hooks/hooks.json`:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/promptup-hook.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Create defaults.json**

`config/defaults.json`:
```json
{
  "enabled": false,
  "mode": "show-and-send",
  "level": "medium",
  "language": "auto",
  "minLength": 20,
  "skipPatterns": [],
  "customInstructions": ""
}
```

- [ ] **Step 4: Create MIT LICENSE file**

Write standard MIT license with copyright `2026 Voy Zeglin` to `LICENSE`.

- [ ] **Step 5: Commit scaffold**

```bash
git add .claude-plugin/plugin.json hooks/hooks.json config/defaults.json LICENSE
git commit -m "feat: add plugin scaffold — manifest, hooks config, defaults, license"
```

---

### Task 2a: Test Fixtures + Config Tests

**Files:**
- Create: `tests/fixtures/valid_config.json`
- Create: `tests/fixtures/invalid_json.json`
- Create: `tests/fixtures/invalid_fields.json`
- Create: `tests/fixtures/partial_config.json`
- Create: `tests/test_config.bats`

- [ ] **Step 1: Install bats-core test framework**

```bash
apt-get install -y bats 2>/dev/null || brew install bats-core 2>/dev/null || git clone https://github.com/bats-core/bats-core.git tests/bats
```

- [ ] **Step 2: Create test fixtures**

`tests/fixtures/valid_config.json`:
```json
{
  "enabled": true,
  "mode": "show-and-send",
  "level": "deep",
  "language": "en+pl",
  "minLength": 30,
  "skipPatterns": ["cheers"],
  "customInstructions": "Use formal tone"
}
```

`tests/fixtures/invalid_json.json`:
```
{not valid json
```

`tests/fixtures/invalid_fields.json`:
```json
{
  "enabled": true,
  "mode": "invalid_mode",
  "level": "ultra",
  "language": "xxx",
  "minLength": -5,
  "skipPatterns": [],
  "customInstructions": ""
}
```

`tests/fixtures/partial_config.json`:
```json
{
  "enabled": true,
  "level": "light"
}
```

- [ ] **Step 3: Write failing tests for config reading**

`tests/test_config.bats`:
```bash
#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/../hooks" && pwd)"

setup() {
  source "$HOOKS_DIR/lib/config.sh"
  export PROMPTUP_CONFIG_PATH="$SCRIPT_DIR/fixtures/valid_config.json"
  export PROMPTUP_DEFAULTS_PATH="$SCRIPT_DIR/../config/defaults.json"
}

@test "load_config reads enabled field from valid config" {
  load_config
  [ "$PROMPTUP_ENABLED" = "true" ]
}

@test "load_config reads level field from valid config" {
  load_config
  [ "$PROMPTUP_LEVEL" = "deep" ]
}

@test "load_config reads language field from valid config" {
  load_config
  [ "$PROMPTUP_LANGUAGE" = "en+pl" ]
}

@test "load_config reads minLength field from valid config" {
  load_config
  [ "$PROMPTUP_MIN_LENGTH" = "30" ]
}

@test "load_config reads skipPatterns as newline-separated list" {
  load_config
  echo "$PROMPTUP_SKIP_PATTERNS" | grep -q "cheers"
}

@test "load_config reads customInstructions from valid config" {
  load_config
  [ "$PROMPTUP_CUSTOM_INSTRUCTIONS" = "Use formal tone" ]
}

@test "load_config treats missing file as disabled" {
  export PROMPTUP_CONFIG_PATH="/nonexistent/path.json"
  load_config
  [ "$PROMPTUP_ENABLED" = "false" ]
}

@test "load_config treats invalid JSON as disabled and warns to stderr" {
  export PROMPTUP_CONFIG_PATH="$SCRIPT_DIR/fixtures/invalid_json.json"
  load_config 2>stderr_output.txt
  [ "$PROMPTUP_ENABLED" = "false" ]
  grep -q "Config error" stderr_output.txt
  rm -f stderr_output.txt
}

@test "load_config falls back invalid fields to defaults with stderr warning" {
  export PROMPTUP_CONFIG_PATH="$SCRIPT_DIR/fixtures/invalid_fields.json"
  load_config 2>stderr_output.txt
  [ "$PROMPTUP_MODE" = "show-and-send" ]  # fell back from "invalid_mode"
  [ "$PROMPTUP_LEVEL" = "medium" ]          # fell back from "ultra"
  [ "$PROMPTUP_LANGUAGE" = "auto" ]         # fell back from "xxx" (3 letters, fails format)
  [ "$PROMPTUP_MIN_LENGTH" = "20" ]         # fell back from -5
  grep -q "Invalid value" stderr_output.txt
  rm -f stderr_output.txt
}

@test "load_config fills missing fields with defaults" {
  export PROMPTUP_CONFIG_PATH="$SCRIPT_DIR/fixtures/partial_config.json"
  load_config
  [ "$PROMPTUP_ENABLED" = "true" ]
  [ "$PROMPTUP_LEVEL" = "light" ]
  [ "$PROMPTUP_MODE" = "show-and-send" ]     # from defaults
  [ "$PROMPTUP_MIN_LENGTH" = "20" ]           # from defaults
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
bats tests/test_config.bats
```

Expected: FAIL — `hooks/lib/config.sh` does not exist.

- [ ] **Step 5: Commit test fixtures and test file**

```bash
git add tests/
git commit -m "test: add config test fixtures and failing tests"
```

---

### Task 2b: Config Library Implementation

**Files:**
- Create: `hooks/lib/config.sh`

- [ ] **Step 1: Implement config.sh**

`hooks/lib/config.sh`:
```bash
#!/usr/bin/env bash
# PromptUp config reader — loads and validates ~/.claude/promptup.json

PROMPTUP_CONFIG_PATH="${PROMPTUP_CONFIG_PATH:-$HOME/.claude/promptup.json}"
PROMPTUP_DEFAULTS_PATH="${PROMPTUP_DEFAULTS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/defaults.json}"

# Valid enum values
_VALID_MODES="silent show-and-confirm show-and-send"
_VALID_LEVELS="light medium deep"

_json_field() {
  local file="$1" field="$2"
  _PROMPTUP_FILE="$file" _PROMPTUP_FIELD="$field" python3 - <<'PYEOF' 2>/dev/null
import json, os, sys
try:
    with open(os.environ['_PROMPTUP_FILE']) as f:
        data = json.load(f)
    val = data.get(os.environ['_PROMPTUP_FIELD'], '')
    if isinstance(val, list):
        print('\n'.join(str(v) for v in val))
    elif isinstance(val, bool):
        print('true' if val else 'false')
    else:
        print(val if val is not None else '')
except:
    sys.exit(1)
PYEOF
}

_validate_enum() {
  local value="$1" valid_values="$2"
  echo "$valid_values" | tr ' ' '\n' | grep -qx "$value"
}

_validate_language() {
  local lang="$1"
  [ "$lang" = "auto" ] && return 0
  local code
  while IFS= read -r code; do
    echo "$code" | grep -qE '^[a-z]{2}$' || return 1
  done <<< "$(echo "$lang" | tr '+' '\n')"
}

_load_defaults() {
  local def="$PROMPTUP_DEFAULTS_PATH"
  PROMPTUP_ENABLED="false"
  PROMPTUP_MODE="$(_json_field "$def" "mode")"
  PROMPTUP_LEVEL="$(_json_field "$def" "level")"
  PROMPTUP_LANGUAGE="$(_json_field "$def" "language")"
  PROMPTUP_MIN_LENGTH="$(_json_field "$def" "minLength")"
  PROMPTUP_SKIP_PATTERNS=""
  PROMPTUP_CUSTOM_INSTRUCTIONS=""
}

load_config() {
  local def="$PROMPTUP_DEFAULTS_PATH"

  # If config file doesn't exist, use all defaults (disabled)
  if [ ! -f "$PROMPTUP_CONFIG_PATH" ]; then
    _load_defaults
    return 0
  fi

  # Try to parse config — if invalid JSON, treat as disabled
  if ! _PROMPTUP_FILE="$PROMPTUP_CONFIG_PATH" python3 -c "import json, os; json.load(open(os.environ['_PROMPTUP_FILE']))" 2>/dev/null; then
    echo "[PromptUp] Config error: invalid JSON in $PROMPTUP_CONFIG_PATH, skipping" >&2
    _load_defaults
    return 0
  fi

  local cfg="$PROMPTUP_CONFIG_PATH"

  # Read enabled (boolean, default false)
  PROMPTUP_ENABLED="$(_json_field "$cfg" "enabled")"
  [ "$PROMPTUP_ENABLED" != "true" ] && PROMPTUP_ENABLED="false"

  # Read and validate mode
  PROMPTUP_MODE="$(_json_field "$cfg" "mode")"
  if [ -z "$PROMPTUP_MODE" ] || ! _validate_enum "$PROMPTUP_MODE" "$_VALID_MODES"; then
    [ -n "$PROMPTUP_MODE" ] && echo "[PromptUp] Invalid value for \"mode\": \"$PROMPTUP_MODE\", using default \"$(_json_field "$def" "mode")\"" >&2
    PROMPTUP_MODE="$(_json_field "$def" "mode")"
  fi

  # Read and validate level
  PROMPTUP_LEVEL="$(_json_field "$cfg" "level")"
  if [ -z "$PROMPTUP_LEVEL" ] || ! _validate_enum "$PROMPTUP_LEVEL" "$_VALID_LEVELS"; then
    [ -n "$PROMPTUP_LEVEL" ] && echo "[PromptUp] Invalid value for \"level\": \"$PROMPTUP_LEVEL\", using default \"$(_json_field "$def" "level")\"" >&2
    PROMPTUP_LEVEL="$(_json_field "$def" "level")"
  fi

  # Read and validate language
  PROMPTUP_LANGUAGE="$(_json_field "$cfg" "language")"
  if [ -z "$PROMPTUP_LANGUAGE" ] || ! _validate_language "$PROMPTUP_LANGUAGE"; then
    [ -n "$PROMPTUP_LANGUAGE" ] && echo "[PromptUp] Invalid value for \"language\": \"$PROMPTUP_LANGUAGE\", using default \"$(_json_field "$def" "language")\"" >&2
    PROMPTUP_LANGUAGE="$(_json_field "$def" "language")"
  fi

  # Read and validate minLength
  PROMPTUP_MIN_LENGTH="$(_json_field "$cfg" "minLength")"
  if ! echo "$PROMPTUP_MIN_LENGTH" | grep -qE '^[0-9]+$'; then
    [ -n "$PROMPTUP_MIN_LENGTH" ] && echo "[PromptUp] Invalid value for \"minLength\": \"$PROMPTUP_MIN_LENGTH\", using default \"$(_json_field "$def" "minLength")\"" >&2
    PROMPTUP_MIN_LENGTH="$(_json_field "$def" "minLength")"
  fi

  # Read skipPatterns (newline-separated)
  PROMPTUP_SKIP_PATTERNS="$(_json_field "$cfg" "skipPatterns")"

  # Read customInstructions
  PROMPTUP_CUSTOM_INSTRUCTIONS="$(_json_field "$cfg" "customInstructions")"
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
bats tests/test_config.bats
```

Expected: All tests PASS.

- [ ] **Step 3: Commit config library**

```bash
git add hooks/lib/config.sh
git commit -m "feat: add config reader with validation"
```

---

### Task 3: Smart-Skip Library (TDD)

**Files:**
- Create: `hooks/lib/skip.sh`
- Create: `tests/test_skip.bats`

- [ ] **Step 1: Write failing tests for smart-skip**

`tests/test_skip.bats`:
```bash
#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/../hooks" && pwd)"

setup() {
  source "$HOOKS_DIR/lib/skip.sh"
  PROMPTUP_MIN_LENGTH=20
  PROMPTUP_SKIP_PATTERNS=""
}

@test "should_skip returns 0 (skip) for below-threshold prompts" {
  should_skip "help me out"
}

@test "should_skip returns 0 (skip) for built-in trivial: yes" {
  should_skip "yes"
}

@test "should_skip returns 0 (skip) for built-in trivial: lgtm" {
  should_skip "lgtm"
}

@test "should_skip returns 0 (skip) for built-in trivial with punctuation: go ahead." {
  should_skip "go ahead."
}

@test "should_skip returns 0 (skip) for built-in trivial with caps: LOOKS GOOD" {
  should_skip "LOOKS GOOD"
}

@test "should_skip returns 0 (skip) for slash commands" {
  should_skip "/help"
}

@test "should_skip returns 0 (skip) for /pp command" {
  should_skip "/pp fix my code to use better error handling"
}

@test "should_skip returns 0 (skip) for pure numbers" {
  should_skip "42"
}

@test "should_skip returns 0 (skip) for single character" {
  should_skip "y"
}

@test "should_skip returns 1 (don't skip) for real prompts" {
  ! should_skip "Please refactor the authentication module to use JWT tokens instead of sessions"
}

@test "should_skip returns 1 (don't skip) for medium prompts above threshold" {
  ! should_skip "Add error handling to the API endpoint"
}

@test "should_skip respects custom skip patterns" {
  PROMPTUP_SKIP_PATTERNS="cheers
bye"
  should_skip "cheers"
}

@test "should_skip respects custom skip patterns with punctuation" {
  PROMPTUP_SKIP_PATTERNS="cheers
bye"
  should_skip "Cheers!"
}

@test "should_skip with minLength 0 disables length check" {
  PROMPTUP_MIN_LENGTH=0
  ! should_skip "fix the bug in auth"
}

@test "should_skip still catches trivials even with minLength 0" {
  PROMPTUP_MIN_LENGTH=0
  should_skip "yes"
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/test_skip.bats
```

Expected: FAIL — `hooks/lib/skip.sh` does not exist.

- [ ] **Step 3: Implement skip.sh**

`hooks/lib/skip.sh`:
```bash
#!/usr/bin/env bash
# PromptUp smart-skip detection

_BUILTIN_TRIVIALS="yes
no
ok
okay
sure
yep
nope
right
correct
continue
go ahead
do it
fix it
try again
looks good
lgtm
ship it
done
thanks
thank you
got it
understood
agreed
perfect
great
good
fine
cool
nice
awesome"

_strip_punctuation() {
  echo "$1" | sed 's/[.!?,;:]*$//'
}

should_skip() {
  local prompt="$1"

  # Slash commands always skip first
  if echo "$prompt" | grep -qE '^\s*/'; then
    return 0
  fi

  # Trim whitespace
  local trimmed
  trimmed="$(echo "$prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # Single character — skip
  if [ "${#trimmed}" -le 1 ]; then
    return 0
  fi

  # Pure numbers — skip
  if echo "$trimmed" | grep -qE '^[0-9]+$'; then
    return 0
  fi

  # Length check (deferred so trivials are still caught at minLength=0)
  local below_min_length=false
  if [ "$PROMPTUP_MIN_LENGTH" -gt 0 ] 2>/dev/null && [ "${#trimmed}" -lt "$PROMPTUP_MIN_LENGTH" ]; then
    below_min_length=true
  fi

  # Lowercase and strip punctuation for matching
  local normalized
  normalized="$(echo "$trimmed" | tr '[:upper:]' '[:lower:]')"
  normalized="$(_strip_punctuation "$normalized")"

  # Check built-in trivials
  if echo "$_BUILTIN_TRIVIALS" | grep -qxF "$normalized"; then
    return 0
  fi

  # Check user-defined skip patterns
  if [ -n "$PROMPTUP_SKIP_PATTERNS" ]; then
    if echo "$PROMPTUP_SKIP_PATTERNS" | tr '[:upper:]' '[:lower:]' | grep -qxF "$normalized"; then
      return 0
    fi
  fi

  # Apply deferred length check
  if [ "$below_min_length" = true ]; then
    return 0
  fi

  # Prompt qualifies for rewriting
  return 1
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/test_skip.bats
```

Expected: All tests PASS.

- [ ] **Step 5: Commit smart-skip library**

```bash
git add hooks/lib/skip.sh tests/test_skip.bats
git commit -m "feat: add smart-skip detection with tests"
```

---

## Chunk 2: Hook Script + Skills

### Task 4: Hook Script (Context Injection)

**Files:**
- Create: `hooks/promptup-hook.sh`
- Create: `tests/test_hook.bats`

- [ ] **Step 1: Write failing integration tests**

`tests/test_hook.bats`:
```bash
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
  # Build JSON stdin matching Claude Code's UserPromptSubmit format
  local prompt="$1"
  python3 -c "import json; print(json.dumps({'session_id':'test','hook_event_name':'UserPromptSubmit','prompt':$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$prompt"),'cwd':'/tmp'}))"
}

@test "hook passes through when config missing (disabled)" {
  rm -f "$PROMPTUP_CONFIG_PATH"
  run bash -c '$(_make_stdin "Please fix the auth bug in the login module") | '"$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through when enabled=false" {
  echo '{"enabled": false}' > "$PROMPTUP_CONFIG_PATH"
  _make_stdin "Please fix the auth bug in the login module" | run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through trivial prompts when enabled" {
  echo '{"enabled": true}' > "$PROMPTUP_CONFIG_PATH"
  _make_stdin "yes" | run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook passes through slash commands when enabled" {
  echo '{"enabled": true}' > "$PROMPTUP_CONFIG_PATH"
  _make_stdin "/help" | run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook outputs JSON with additionalContext for qualifying prompts" {
  echo '{"enabled": true, "mode": "show-and-send", "level": "medium"}' > "$PROMPTUP_CONFIG_PATH"
  _make_stdin "Please fix the authentication bug in the login module" | run "$HOOK"
  [ "$status" -eq 0 ]
  # Should output valid JSON with hookSpecificOutput
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hookSpecificOutput' in d"
}

@test "hook outputs additionalContext containing rewriting instructions" {
  echo '{"enabled": true, "mode": "show-and-send", "level": "deep"}' > "$PROMPTUP_CONFIG_PATH"
  _make_stdin "fix the bug were users cant login" | run "$HOOK"
  [ "$status" -eq 0 ]
  # additionalContext should contain rewriting instructions
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
  _make_stdin "Please fix the authentication bug in the login module" | run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/test_hook.bats
```

Expected: FAIL — `hooks/promptup-hook.sh` does not exist.

- [ ] **Step 3: Implement the hook script**

`hooks/promptup-hook.sh`:
```bash
#!/usr/bin/env bash
# PromptUp — UserPromptSubmit hook
# Receives JSON on stdin, outputs JSON with additionalContext to stdout.
# Exit 0 with no output = pass through. Exit 0 with JSON = inject context.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/skip.sh"

# Extract .prompt from JSON stdin
STDIN_JSON="$(cat)"
PROMPT="$(echo "$STDIN_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)" || {
  # Can't parse stdin — fail-open
  exit 0
}

# Load config
load_config

# If not enabled, pass through
if [ "$PROMPTUP_ENABLED" != "true" ]; then
  exit 0
fi

# Smart-skip check
if should_skip "$PROMPT"; then
  exit 0
fi

# Build the rewriting instructions for additionalContext
build_rewrite_instructions() {
  local level="$1" mode="$2" language="$3" custom="$4"

  cat <<'INSTRUCTIONS'
[PromptUp — Prompt Enhancement System]

You have received a user prompt that should be improved before you respond to it. Follow these steps:

1. REWRITE the user's prompt to be clearer, more specific, and more effective
2. DISPLAY the rewritten prompt (unless mode is silent)
3. RESPOND to the rewritten version, not the original

CORE RULES:
- Preserve the user's original intent exactly — improve HOW they ask, never WHAT they ask
- Do not add requirements, features, or scope the user did not express or imply
- If the prompt is already well-formed and needs no changes, skip the rewrite and respond normally
INSTRUCTIONS

  case "$level" in
    light)
      cat <<'INSTRUCTIONS'

LEVEL: Light
- Fix typos, grammar, punctuation, and clarity
- Do not change structure or add new content
INSTRUCTIONS
      ;;
    medium)
      cat <<'INSTRUCTIONS'

LEVEL: Medium
- Fix typos, grammar, punctuation, and clarity
- Add specificity and remove ambiguity where possible
- Improve structure and formatting for readability
- Break complex requests into clear, ordered steps if appropriate
INSTRUCTIONS
      ;;
    deep)
      cat <<'INSTRUCTIONS'

LEVEL: Deep
- Fix typos, grammar, punctuation, and clarity
- Add specificity and remove ambiguity where possible
- Improve structure and formatting for readability
- Consider the codebase context and add relevant technical constraints
- Suggest scope boundaries if the request is vague
- Structure as actionable instructions with clear success criteria
INSTRUCTIONS
      ;;
  esac

  # Language instruction
  case "$language" in
    auto)
      echo ""
      echo "LANGUAGE: Detect the language of the user's prompt and rewrite in the same language."
      ;;
    *+*)
      echo ""
      echo "LANGUAGE: The user is bilingual. Detect which of these languages the prompt is in: ${language//+/, }. Rewrite in that language. If ambiguous, use ${language%%+*}."
      ;;
    *)
      echo ""
      echo "LANGUAGE: Rewrite in $language regardless of input language."
      ;;
  esac

  # Display mode instruction
  case "$mode" in
    silent)
      cat <<'INSTRUCTIONS'

DISPLAY: Do NOT show the rewrite. Silently interpret the improved version and respond to it directly.
INSTRUCTIONS
      ;;
    show-and-send|show-and-confirm)
      cat <<'INSTRUCTIONS'

DISPLAY: Before your response, show the rewritten prompt in this exact format:

[PromptUp] Rewritten (LEVEL):
> <your rewritten prompt here>

Then respond to the rewritten version below that.
If the prompt needs no changes, skip the [PromptUp] block and respond normally.
INSTRUCTIONS
      ;;
  esac

  # Custom instructions
  if [ -n "$custom" ]; then
    echo ""
    echo "ADDITIONAL INSTRUCTIONS: $custom"
  fi
}

INSTRUCTIONS="$(build_rewrite_instructions "$PROMPTUP_LEVEL" "$PROMPTUP_MODE" "$PROMPTUP_LANGUAGE" "$PROMPTUP_CUSTOM_INSTRUCTIONS")"

# Replace LEVEL placeholder with actual level name
INSTRUCTIONS="${INSTRUCTIONS//LEVEL/$PROMPTUP_LEVEL}"

# Output JSON with additionalContext
python3 -c "
import json, os, sys
instructions = os.environ['PROMPTUP_INSTRUCTIONS']
output = {
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': instructions
    }
}
print(json.dumps(output))
" <<< "" 2>/dev/null

exit 0
```

Note: The `PROMPTUP_INSTRUCTIONS` env var is set before calling python3:

Insert before the python3 call:
```bash
export PROMPTUP_INSTRUCTIONS="$INSTRUCTIONS"
```

- [ ] **Step 4: Make hook executable**

```bash
chmod +x hooks/promptup-hook.sh
```

- [ ] **Step 5: Run integration tests**

```bash
bats tests/test_hook.bats
```

Expected: All tests PASS.

- [ ] **Step 6: Commit hook script**

```bash
git add hooks/promptup-hook.sh tests/test_hook.bats
git commit -m "feat: add hook script with smart-skip and context injection"
```

---

### Task 5: `/pp` Skill

**Files:**
- Create: `skills/pp/SKILL.md`

- [ ] **Step 1: Write the /pp skill**

`skills/pp/SKILL.md`:
````markdown
---
name: pp
description: Rewrite a prompt to be clearer, more specific, and more effective for AI
---

# PromptUp — Prompt Rewriter

You are PromptUp, a prompt improvement assistant. The user has asked you to rewrite their prompt.

## Instructions

1. Read the user's configuration from `~/.claude/promptup.json`. If the file doesn't exist, use these defaults:
   - mode: show-and-send
   - level: medium
   - language: auto
   - customInstructions: (none)

2. Based on the configured **level**, rewrite the user's prompt:

   **light:** Fix typos, grammar, punctuation, and clarity. Don't change structure or add content.

   **medium:** Light + add specificity, remove ambiguity, improve structure and formatting, break complex requests into ordered steps if appropriate.

   **deep:** Medium + consider the current codebase context (working directory, recent files, project structure), add relevant technical constraints, suggest scope boundaries if vague, structure as actionable instructions with clear success criteria.

3. **Core rules:**
   - Preserve the user's original intent exactly — improve HOW they ask, never WHAT they ask
   - Do not add requirements, features, or scope the user did not express or imply
   - Detect the input language and respond in kind (unless `language` config overrides this)
   - If `customInstructions` is set, apply those additional instructions

4. **Display based on configured mode:**

   - **silent:** Output only the rewritten prompt with no commentary, then respond to it
   - **show-and-send:** Show the rewrite like this, then respond to the rewritten prompt:
     ```
     [PromptUp] Rewritten (level):
     > <rewritten prompt>
     ```
   - **show-and-confirm:** Show original and rewritten side by side, ask user to confirm:
     ```
     [PromptUp] Original:
     > <original prompt>

     [PromptUp] Rewritten (level):
     > <rewritten prompt>

     Send the rewritten version? (yes/no/edit)
     ```

5. **No-change case:** If the prompt is already well-formed and rewriting produces no meaningful change, display:
   ```
   [PromptUp] Your prompt looks good as-is — sent unchanged.
   ```
   Then respond to the original prompt normally.

6. After displaying, respond to the rewritten prompt as if the user had typed it.
````

- [ ] **Step 2: Commit /pp skill**

```bash
git add skills/pp/SKILL.md
git commit -m "feat: add /pp manual rewriting skill"
```

---

### Task 6: `/pp-config` Skill

**Files:**
- Create: `skills/pp-config/SKILL.md`

- [ ] **Step 1: Write the /pp-config skill**

`skills/pp-config/SKILL.md`:
````markdown
---
name: pp-config
description: Configure PromptUp settings — enable/disable, set mode, level, language, and more
---

# PromptUp Configuration Manager

You manage the PromptUp configuration file at `~/.claude/promptup.json`.

## Config File Lifecycle

If `~/.claude/promptup.json` does not exist, create it with these defaults before applying any changes:

```json
{
  "enabled": false,
  "mode": "show-and-send",
  "level": "medium",
  "language": "auto",
  "minLength": 20,
  "skipPatterns": [],
  "customInstructions": ""
}
```

## Commands

Parse the user's input to determine which command they're running:

### `/pp-config` (no arguments)
Read `~/.claude/promptup.json` and display all current settings in a readable table format. If the file doesn't exist, show the defaults and note that PromptUp is in manual-only mode.

### `/pp-config enable`
Set `"enabled": true` in the config file. Confirm with: "PromptUp is now active — your prompts will be automatically improved."

### `/pp-config disable`
Set `"enabled": false` in the config file. Confirm with: "PromptUp hook disabled. Use /pp for manual rewriting."

### `/pp-config set <key> <value>`
Update a specific field. Validate before writing:

**Validation rules:**
- **Unknown keys:** Reject with error listing valid keys: `enabled, mode, level, language, minLength, skipPatterns, customInstructions`
- **enabled:** Must be `true` or `false`
- **mode:** Must be `silent`, `show-and-confirm`, or `show-and-send`
- **level:** Must be `light`, `medium`, or `deep`
- **language:** Must be `auto`, a valid ISO 639-1 two-letter code (e.g., `en`, `pl`, `pt`), or `+`-joined codes for bilingual (e.g., `en+pl`). Each code must be exactly 2 lowercase letters.
- **minLength:** Must be a non-negative integer (0 is valid). Negative values are rejected.
- **skipPatterns:** Accept as a comma-separated list. Store as JSON array. Example: `/pp-config set skipPatterns cheers,bye,brb`
- **customInstructions:** Max 500 characters. Reject (don't truncate) if exceeded.

On success, confirm the change. On failure, show the error and the valid options.

### `/pp-config reset`
Replace the config file with the defaults above. Confirm with: "PromptUp settings reset to defaults."

## Output Style

Be concise. Use tables for showing settings. Use code blocks for JSON. Confirm every action.
````

- [ ] **Step 2: Commit /pp-config skill**

```bash
git add skills/pp-config/SKILL.md
git commit -m "feat: add /pp-config configuration management skill"
```

---

## Chunk 3: Documentation + Polish

### Task 7: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

`README.md`:
````markdown
# PromptUp

A Claude Code plugin that automatically improves your prompts — better language, clearer instructions, smarter structure.

## Installation

**From the official Anthropic marketplace** (once submitted):

```bash
/plugin install promptup
```

**From GitHub** (available now):

```bash
/plugin marketplace add zeglin/promptup
/plugin install promptup
```

## Usage

### Manual Mode

Use `/pp` followed by your prompt:

```
/pp fix the bug where users cant login after password reset
```

PromptUp rewrites it into a clearer, more actionable prompt and responds to the improved version.

### Always-On Mode

Enable automatic prompt improvement for every message:

```
/pp-config enable
```

PromptUp intercepts your prompts, improves them, and shows what changed:

```
[PromptUp] Rewritten (medium):
> Fix the bug where users cannot log in after a password reset. Investigate the password reset flow, check whether the new password hash is stored correctly, and verify the login validation logic accepts the updated credentials.
```

Short/trivial prompts ("yes", "ok", "continue") are automatically skipped.

### Configuration

View current settings:

```
/pp-config
```

Change settings:

```
/pp-config set level deep        # light, medium, deep
/pp-config set mode silent       # silent, show-and-confirm, show-and-send
/pp-config set language en+pl    # auto, en, pl, en+pl, etc.
/pp-config set minLength 10      # minimum characters to trigger rewrite
/pp-config disable               # turn off always-on mode
/pp-config reset                 # restore defaults
```

### Settings Reference

| Setting | Default | Options |
|---------|---------|---------|
| `enabled` | `false` | `true`, `false` |
| `mode` | `show-and-send` | `silent`, `show-and-confirm`, `show-and-send` |
| `level` | `medium` | `light`, `medium`, `deep` |
| `language` | `auto` | `auto`, ISO 639-1 code, or `+`-joined codes |
| `minLength` | `20` | Any non-negative integer |
| `skipPatterns` | `[]` | Comma-separated list of phrases to skip |
| `customInstructions` | `""` | Extra instructions (max 500 chars) |

## How It Works

PromptUp uses Claude Code's hook system. When always-on mode is enabled, a `UserPromptSubmit` hook runs on each prompt:

1. **Smart-skip** checks if the prompt is trivial, a slash command, or below the length threshold
2. If the prompt qualifies, the hook injects **rewriting instructions** into Claude's context
3. Claude rewrites the prompt, displays the improved version, and responds to it
4. No external API calls — Claude itself does the rewriting using the current session model

## Rewrite Levels

- **light** — Fix typos, grammar, punctuation, clarity
- **medium** — Light + add specificity, structure, formatting
- **deep** — Medium + codebase context, constraints, scope boundaries

## License

MIT
````

- [ ] **Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add README with installation and usage guide"
```

---

### Task 8: Final Integration + Push

- [ ] **Step 1: Verify all files are committed**

```bash
git status
git log --oneline
```

Expected: Clean working tree with commits for scaffold, config, skip, hook, skills, and README.

- [ ] **Step 2: Run full test suite**

```bash
bats tests/
```

Expected: All tests PASS.

- [ ] **Step 3: Push to GitHub**

```bash
git push origin main
```

- [ ] **Step 4: Manual smoke test**

Install the plugin locally in Claude Code and verify:
1. `/pp fix the bug where users cant login` — produces a rewritten prompt
2. `/pp-config` — shows default settings
3. `/pp-config enable` — enables always-on mode
4. Type a normal prompt — Claude shows `[PromptUp]` rewrite before responding
5. Type "yes" — no rewrite (smart-skip)
6. `/pp-config disable` — disables hook

---
