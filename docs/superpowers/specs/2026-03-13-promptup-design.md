# PromptUp — Design Specification

**Date:** 2026-03-13
**Repository:** github.com/zeglin/promptup
**License:** MIT
**Status:** Draft v2 (revised after hook contract review)

## Overview

PromptUp is a Claude Code plugin that improves user prompts — fixing language, adding clarity and structure, correcting typos, and leveraging codebase context to make prompts more effective.

It operates in two modes:
- **Always-on** — a `UserPromptSubmit` hook injects rewriting instructions into Claude's context via `additionalContext`, so Claude rewrites the prompt as part of its response
- **Manual** — the `/pp` slash command triggers rewriting on demand

### Architecture Note: Why Context Injection

Claude Code's `UserPromptSubmit` hooks **cannot replace** the user's prompt. They can only:
- Pass through (exit 0, no output)
- Add context (exit 0, JSON with `additionalContext`)
- Block (exit 2)

PromptUp uses the **context injection** approach: when always-on mode is active, the hook injects rewriting instructions as `additionalContext`. Claude sees both the original prompt and the instructions, rewrites the prompt inline, displays the improved version as `[PromptUp] ...`, and then responds to the improved version. No external API calls are needed — Claude itself does the rewriting using its own session model.

## Goals

1. Make every prompt clearer, more specific, and more effective for AI consumption
2. Preserve the user's original intent — improve how they ask, never change what they ask
3. Be lightweight and fast — no external API calls, no separate model, zero latency overhead beyond the hook script
4. Be fully configurable — smart defaults, but the user controls everything
5. Be transparent — show users what was changed (default: show-and-send mode)

## Non-Goals

- Multi-platform support (Claude Code only)
- Paid tiers or monetization
- Custom model hosting or fine-tuning
- Prompt history or analytics
- External API calls from the hook (the session model does the rewriting)

## Plugin Structure

```
promptup/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   ├── pp/
│   │   └── SKILL.md             # /pp skill — manual prompt rewriting
│   └── pp-config/
│       └── SKILL.md             # /pp-config skill — toggle settings
├── hooks/
│   ├── hooks.json               # Hook declarations
│   └── promptup-hook.sh         # UserPromptSubmit hook — smart-skip + context injection
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

### 2. Hook Declarations (`hooks/hooks.json`)

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

### 3. `/pp` Skill (`skills/pp/SKILL.md`)

The manual prompt rewriting skill. Invoked as `/pp <user prompt>`.

Reads configuration from `~/.claude/promptup.json` and applies the rewriting instructions at the configured level. In manual mode, Claude itself performs the rewriting — identical to how the always-on hook works, but triggered explicitly.

**Rewriting levels:**

| Level | Behavior |
|-------|----------|
| `light` | Fix typos, grammar, punctuation, clarity. Don't change structure or intent. |
| `medium` | Light + add specificity, remove ambiguity, improve structure, add formatting. |
| `deep` | Medium + consider codebase context, add relevant constraints, suggest scope boundaries, structure as actionable instructions. |

**Core rewriting principles:**

1. **Preserve intent** — never change what the user is asking for
2. **Don't inflate** — don't add requirements the user didn't express or imply
3. **Be transparent** — display the rewritten prompt before responding
4. **Language respect** — detect input language per-prompt and respond in kind
5. **Context-awareness** — in deep mode, consider working directory, conversation, and file context

### 4. `/pp-config` Skill (`skills/pp-config/SKILL.md`)

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
- **`mode`**, **`level`** must be one of their documented enum values.

### 5. Hook Script (`hooks/promptup-hook.sh`)

The `UserPromptSubmit` hook script runs on every prompt submission.

**Input:** Receives JSON on stdin from Claude Code:
```json
{
  "session_id": "abc123",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "the user's prompt text",
  "cwd": "/current/working/directory"
}
```

The hook extracts `.prompt` from the JSON input using `python3` or `jq`.

**Smart-skip decision flow:**

```
JSON stdin arrives → extract .prompt
    │
    ├─ Is PromptUp enabled in config? ── No ──→ Exit 0 (pass through)
    │
    ├─ Is prompt a slash command? ── Yes ──→ Exit 0 (pass through)
    │   (starts with "/")
    │
    ├─ Is prompt below minLength? ── Yes ──→ Exit 0 (pass through)
    │   (default: 20 characters, but trivials still caught)
    │
    ├─ Does prompt match trivial patterns? ── Yes ──→ Exit 0 (pass through)
    │   Built-in: yes, no, ok, sure, yep, nope, right, correct,
    │   continue, go ahead, do it, fix it, try again, looks good,
    │   lgtm, ship it, pure numbers, single characters
    │   + user-defined skipPatterns from config
    │
    └─ Qualifies ──→ Output JSON with additionalContext
```

**Hook output protocol (context injection):**

When a prompt qualifies for rewriting, the hook outputs JSON to stdout:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "<rewriting instructions>"
  }
}
```

The `additionalContext` contains rewriting instructions tailored to the configured level, language, and custom instructions. Claude receives both the user's original prompt and these instructions, then:
1. Rewrites the prompt according to the instructions
2. Displays the improved version as `[PromptUp] Rewritten (level):\n> improved prompt`
3. Responds to the improved version

**Pass through:** Exit 0 with no stdout output. The original prompt is processed normally.

**Fail-open:** Any error (config parse failure, missing python3, etc.) results in exit 0 with no output — the original prompt passes through unchanged. The hook must never block prompt submission.

The hook reads `~/.claude/promptup.json` for configuration. If the file doesn't exist, PromptUp is considered disabled (manual-only mode via `/pp`).

**Config error fallback:** If the config file exists but is malformed JSON or unreadable (permissions error), the hook treats PromptUp as disabled and writes a warning to stderr (e.g., `[PromptUp] Config error: invalid JSON in ~/.claude/promptup.json, skipping`). The hook must never fail hard or block prompt submission.

**Invalid field values:** If the config file contains valid JSON but with invalid field values (e.g., `"language": "xxx"`, `"level": "ultra"`), the hook falls back to the default value for that specific field and writes a warning to stderr. Other valid fields are still respected.

**Hook and `/pp` interaction:** The slash-command check ensures the hook always passes through `/pp` invocations unchanged. There is no double-rewrite risk.

## Configuration

Stored at `~/.claude/promptup.json`.

### Default Values

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

### Field Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | `true` = always-on hook active, `false` = manual `/pp` only |
| `mode` | string | `"show-and-send"` | Display mode: `silent`, `show-and-confirm`, `show-and-send` |
| `level` | string | `"medium"` | Rewrite level: `light`, `medium`, `deep` |
| `language` | string | `"auto"` | `auto` = per-prompt detection, ISO 639-1 code (`en`) = specific language, `+`-joined codes (`en+pl`) = bilingual/multilingual constraint (2+ languages supported) |
| `minLength` | integer | `20` | Minimum character count to trigger rewriting |
| `skipPatterns` | string[] | `[]` | Additional exact-match patterns to skip, case-insensitive (merged with built-in list). Each entry is matched as a full-string exact match against the trimmed, lowercased, punctuation-stripped prompt. Punctuation stripping removes trailing `.!?,;:` characters so that "go ahead." matches "go ahead". |
| `customInstructions` | string | `""` | Extra instructions appended to the rewriting context. Max 500 characters — values exceeding this are rejected by `/pp-config set` with an error (never silently truncated). Treated as plain text. Applied in both `/pp` and hook paths identically. |

**Note:** The `model` field has been removed. Since Claude itself performs the rewriting (no external API call), the session's current model is always used. This is simpler, cheaper, and eliminates the API key requirement.

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
| `silent` | Claude rewrites internally and responds to the improved version. No visible rewrite shown. | Hook + `/pp` |
| `show-and-confirm` | Shows original vs improved, waits for user approval before responding. | `/pp` only |
| `show-and-send` | Claude displays the improved prompt as `[PromptUp] ...` then responds to it. | Hook + `/pp` |

**Note:** `show-and-confirm` is only available in manual `/pp` mode. In always-on hook mode, the rewriting instructions request `show-and-send` behavior regardless, since the hook cannot pause for interactive user input.

### Display Format (`show-and-send`)

When in `show-and-send` mode, Claude displays:

```
[PromptUp] Rewritten (medium):
> <full rewritten prompt>
```

This is shown before Claude's actual response. The user sees their original prompt followed by the improved version, then Claude's response to the improved version.

**No-change suppression:** If Claude determines the prompt is already well-formed and rewriting produces no meaningful change:
- **Hook mode:** Claude simply responds normally without showing a `[PromptUp]` block.
- **`/pp` mode:** Displays `[PromptUp] Your prompt looks good as-is — sent unchanged.`

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
