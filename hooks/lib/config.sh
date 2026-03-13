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
  echo "$valid_values" | tr ' ' '\n' | grep -qxF "$value"
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
