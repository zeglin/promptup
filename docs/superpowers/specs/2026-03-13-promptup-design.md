# PromptUp — Design Specification

**Date:** 2026-03-13
**Repository:** github.com/zeglin/promptup
**License:** MIT
**Status:** Draft

## Overview

PromptUp is a Claude Code plugin that automatically improves user prompts before they reach the model. It fixes language issues, adds clarity and structure, corrects typos, and optionally leverages codebase context to make prompts more effective.

It operates in two modes:
- **Always-on** — a `UserPromptSubmit` hook intercepts and rewrites prompts automatically
- **Manual** — the `/pp` slash command rewrites a single prompt on demand

## Goals

1. Make every prompt clearer, more specific, and more effective for AI consumption
2. Preserve the user's original intent — improve how they ask, never change what they ask
3. Be lightweight and fast — use the cheapest model by default, skip trivial prompts
4. Be fully configurable — smart defaults, but the user controls everything
5. Be transparent — show users what was changed (default: show-and-send mode)

## Non-Goals

- Multi-platform support (Claude Code only)
- Paid tiers or monetization
- Custom model hosting or fine-tuning
- Prompt history or analytics

## Plugin Structure

```
promptup/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   ├── pp.md                    # /pp skill — manual prompt rewriting
│   └── pp-config.md             # /pp-config skill — toggle settings
├── hooks/
│   └── promptup-hook.sh         # UserPromptSubmit hook — smart-skip + auto-rewrite
├── config/
│   └── defaults.json            # Default configuration values
├── LICENSE                      # MIT
└── README.md                    # Installation & usage docs
```

## Components

### 1. Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "promptup",
  "version": "1.0.0",
  "description": "Automatically improves your prompts — better language, clearer instructions, smarter structure",
  "author": "zeglin",
  "license": "MIT",
  "homepage": "https://github.com/zeglin/promptup",
  "skills": [
    "skills/pp.md",
    "skills/pp-config.md"
  ],
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "hooks/promptup-hook.sh"
      }
    ]
  }
}
```

### 2. `/pp` Skill (`skills/pp.md`)

The manual prompt rewriting skill. Invoked as `/pp <user prompt>`.

Reads configuration from `~/.claude/promptup.json` and applies the rewriting prompt at the configured level.

**Rewriting levels:**

| Level | Behavior |
|-------|----------|
| `light` | Fix typos, grammar, punctuation, clarity. Don't change structure or intent. |
| `medium` | Light + add specificity, remove ambiguity, improve structure, add formatting. |
| `deep` | Medium + consider codebase context, add relevant constraints, suggest scope boundaries, structure as actionable instructions. |

**Core rewriting principles:**

1. **Preserve intent** — never change what the user is asking for
2. **Don't inflate** — don't add requirements the user didn't express or imply
3. **Be transparent** — in show-and-send mode, prefix with a `[PromptUp]` marker
4. **Language respect** — detect input language per-prompt and respond in kind
5. **Context-awareness** — in deep mode, consider working directory, conversation, and file context

### 3. `/pp-config` Skill (`skills/pp-config.md`)

Conversational configuration interface. Manages `~/.claude/promptup.json`.

**Config file lifecycle:** If the config file doesn't exist when any `/pp-config` command runs, it is created with all default values first, then the requested change is applied. This ensures the file always contains a complete, valid config. The `/pp` skill also reads this file but never creates it — it uses in-memory defaults if the file is absent.

**Commands:**

| Command | Action |
|---------|--------|
| `/pp-config` | Show current settings |
| `/pp-config enable` | Turn on always-on mode |
| `/pp-config disable` | Turn off always-on mode |
| `/pp-config set <key> <value>` | Change a specific setting |
| `/pp-config reset` | Restore defaults |

**Validation rules for `/pp-config set`:**
- **Unknown keys** are rejected with an error listing valid keys.
- **`minLength`** must be a non-negative integer (0 is valid — disables length-based skipping). Negative values are rejected.
- **`customInstructions`** exceeding 500 characters is rejected (never silently truncated).
- **`language`** must be `auto` or valid ISO 639-1 codes (optionally `+`-joined). Invalid codes are rejected.
- **`mode`**, **`level`**, **`model`** must be one of their documented enum values or a valid full model ID (for `model`).

### 4. Hook Script (`hooks/promptup-hook.sh`)

The `UserPromptSubmit` hook script runs before every prompt when always-on mode is enabled.

**Smart-skip decision flow:**

```
User prompt arrives
    │
    ├─ Is PromptUp enabled in config? ── No ──→ Pass through unchanged
    │
    ├─ Is prompt below minLength? ── Yes ──→ Pass through
    │   (default: 20 characters)
    │
    ├─ Does prompt match trivial patterns? ── Yes ──→ Pass through
    │   Built-in: yes, no, ok, sure, yep, nope, right, correct,
    │   continue, go ahead, do it, fix it, try again, looks good,
    │   lgtm, ship it, pure numbers, single characters
    │   + user-defined skipPatterns from config
    │
    ├─ Is prompt a slash command? ── Yes ──→ Pass through
    │   (starts with "/", including "/pp" — the hook never
    │    intercepts manual /pp invocations)
    │
    └─ Qualifies for rewrite ──→ Inject rewrite instruction
```

The hook reads `~/.claude/promptup.json` for configuration. If the file doesn't exist, PromptUp is considered disabled (manual-only mode via `/pp`).

**Config error fallback:** If the config file exists but is malformed JSON or unreadable (permissions error), the hook treats PromptUp as disabled and writes a warning to stderr (e.g., `[PromptUp] Config error: invalid JSON in ~/.claude/promptup.json, skipping rewrite`). The hook must never fail hard or block prompt submission.

**Invalid field values:** If the config file contains valid JSON but with invalid field values (e.g., `"language": "xx"`, `"level": "ultra"`), the hook falls back to the default value for that specific field and writes a warning to stderr (e.g., `[PromptUp] Invalid value for "language": "xx", using default "auto"`). Other valid fields in the config are still respected — only the invalid field falls back.

**Hook output protocol:** The hook follows the Claude Code `UserPromptSubmit` hook contract:
- **Pass through (no rewrite):** Exit with code 0 and produce no stdout. The original prompt is sent unchanged.
- **Rewrite:** Exit with code 0 and write the rewritten prompt to stdout. This replaces the user's original prompt.
- **Error/abort:** Exit with non-zero code. The original prompt is sent unchanged (fail-open).
- **Display notes:** The `[PromptUp]` display block (in `show-and-send` mode) is written to stderr, which appears in the Claude Code terminal output. It must never be written to stdout, as stdout is the prompt payload.
- **In `/pp` mode:** Output is written as normal skill output to the conversation (not via stdout/stderr).

**Hook and `/pp` interaction:** The slash-command check ensures the hook always passes through `/pp` invocations unchanged. There is no double-rewrite risk — the hook and `/pp` are mutually exclusive code paths.

## Configuration

Stored at `~/.claude/promptup.json`.

### Default Values

```json
{
  "enabled": false,
  "mode": "show-and-send",
  "level": "medium",
  "model": "haiku",
  "language": "auto",
  "minLength": 20,
  "skipPatterns": [],
  "customInstructions": ""
}
```

### Field Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | `true` = always-on hook active, `false` = manual `/pp` only |
| `mode` | string | `"show-and-send"` | Display mode: `silent`, `show-and-confirm`, `show-and-send` |
| `level` | string | `"medium"` | Rewrite level: `light`, `medium`, `deep` |
| `model` | string | `"haiku"` | Model for rewriting: `haiku`, `sonnet`, `opus` |
| `language` | string | `"auto"` | `auto` = per-prompt detection, ISO 639-1 code (`en`) = specific language, `+`-joined codes (`en+pl`) = bilingual/multilingual constraint (2+ languages supported) |
| `minLength` | integer | `20` | Minimum character count to trigger rewriting |
| `skipPatterns` | string[] | `[]` | Additional exact-match patterns to skip, case-insensitive (merged with built-in list). Each entry is matched as a full-string exact match against the trimmed, lowercased, punctuation-stripped prompt. Punctuation stripping removes trailing `.!?,;:` characters so that "go ahead." matches "go ahead". |
| `customInstructions` | string | `""` | Extra instructions appended after the rewriting system prompt but before the user's prompt. Max 500 characters — values exceeding this are rejected by `/pp-config set` with an error (never silently truncated). Treated as plain text (no prompt template syntax). Applied in both `/pp` and hook paths identically. |

### Language Handling

| Value | Behavior |
|-------|----------|
| `auto` | Detects the language of each individual prompt and rewrites in that same language |
| Specific code (`en`, `pl`, `pt`...) | Always rewrites in that language regardless of input |
| Bilingual (`en+pl`, `en+pt`...) | Detects which of the specified languages the prompt is in, rewrites in that language. Falls back to the first language if ambiguous. |

`auto` is the default and handles bilingual users naturally — each prompt is detected independently.

**Language codes:** Must be valid ISO 639-1 two-letter codes (e.g., `en`, `pl`, `pt`, `es`, `de`, `fr`, `ja`, `zh`). The bilingual format supports 2 or more languages joined with `+` (e.g., `en+pl+pt`). Invalid codes are rejected by `/pp-config set` with an error message listing valid examples.

### Display Modes

| Mode | Behavior | Availability |
|------|----------|-------------|
| `silent` | Rewrites and sends directly. No indication to user. | Hook + `/pp` |
| `show-and-confirm` | Shows original vs improved, waits for user approval before sending. | `/pp` only |
| `show-and-send` | Displays a brief `[PromptUp]` note showing what changed, sends automatically. | Hook + `/pp` |

**Note:** `show-and-confirm` is only available in manual `/pp` mode, where the skill can present options and wait for user input. In always-on hook mode, `show-and-confirm` is treated as `show-and-send` with a warning written to stderr (e.g., `[PromptUp] show-and-confirm is not supported in hook mode, using show-and-send`). This is because shell hooks cannot pause for interactive user input.

### Display Format (`show-and-send`)

When in `show-and-send` mode, the output format is:

```
[PromptUp] Rewritten (medium):
> <full rewritten prompt>
```

This shows the rewrite level used and the complete rewritten prompt so the user can see exactly what was sent. The same format is used in both hook and `/pp` paths for consistency.

**No-change suppression:** If the rewritten prompt is identical to the original (or differs only in whitespace):
- **Hook mode:** The `[PromptUp]` display is suppressed entirely and the original prompt is sent unchanged (silent pass-through).
- **`/pp` mode:** Displays `[PromptUp] Your prompt looks good as-is — sent unchanged.` so the user knows the command worked.

## Distribution

### Installation

```bash
# From the official marketplace (once submitted)
/plugin install promptup

# From GitHub
/plugin marketplace add zeglin/promptup
/plugin install promptup
```

### Post-Install

1. `/pp <prompt>` works immediately for manual use
2. `/pp-config enable` activates always-on mode
3. No API keys, no setup, no external dependencies

### Repository

- **URL:** github.com/zeglin/promptup
- **License:** MIT
- **Target:** Official Anthropic marketplace submission

## Model Versioning

The `model` field uses friendly aliases that map to the latest available version of each model tier:

| Alias | Floating API alias |
|-------|-------------------|
| `haiku` | `claude-haiku-4-5` |
| `sonnet` | `claude-sonnet-4-6` |
| `opus` | `claude-opus-4-6` |

These friendly names map to Anthropic's floating aliases, which always resolve to the latest version of that model tier. The exact alias strings may change as Anthropic releases new models — the implementation should resolve these at build time against the current Anthropic model catalog. Users who need a pinned snapshot can set the full versioned model ID directly (e.g., `"model": "claude-haiku-4-5-20251001"`) — any valid Anthropic model ID is accepted.
