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
