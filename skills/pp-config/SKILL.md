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
