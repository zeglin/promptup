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

Rewrite level: Light
- Fix typos, grammar, punctuation, and clarity
- Do not change structure or add new content
INSTRUCTIONS
      ;;
    medium)
      cat <<'INSTRUCTIONS'

Rewrite level: Medium
- Fix typos, grammar, punctuation, and clarity
- Add specificity and remove ambiguity where possible
- Improve structure and formatting for readability
- Break complex requests into clear, ordered steps if appropriate
INSTRUCTIONS
      ;;
    deep)
      cat <<'INSTRUCTIONS'

Rewrite level: Deep
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

[PromptUp] Rewritten ({{LEVEL}}):
> <your rewritten prompt here>

Then respond to the rewritten version below that.
If the prompt needs no changes, skip the [PromptUp] block and respond normally.
INSTRUCTIONS
      ;;
  esac

  # Custom instructions
  if [ -n "$custom" ]; then
    echo ""
    printf 'ADDITIONAL INSTRUCTIONS: %s\n' "$custom"
  fi
}

INSTRUCTIONS="$(build_rewrite_instructions "$PROMPTUP_LEVEL" "$PROMPTUP_MODE" "$PROMPTUP_LANGUAGE" "$PROMPTUP_CUSTOM_INSTRUCTIONS")"

# Replace {{LEVEL}} placeholder with actual level name
INSTRUCTIONS="${INSTRUCTIONS//\{\{LEVEL\}\}/$PROMPTUP_LEVEL}"

# Output JSON with additionalContext
export PROMPTUP_INSTRUCTIONS="$INSTRUCTIONS"
python3 - <<'PYEOF' 2>/dev/null
import json, os
instructions = os.environ['PROMPTUP_INSTRUCTIONS']
output = {
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': instructions
    }
}
print(json.dumps(output))
PYEOF

exit 0
