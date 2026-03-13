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
