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
