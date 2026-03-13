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
