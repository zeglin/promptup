# Changelog

All notable changes to PromptUp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-13

### Added

- `/pp` skill for manual prompt rewriting on demand
- `/pp-config` skill for managing settings conversationally
- Always-on mode via `UserPromptSubmit` hook with context injection
- Three rewrite levels: light (grammar/typos), medium (structure/clarity), deep (codebase-aware)
- Automatic per-prompt language detection
- Bilingual mode with `+`-joined ISO 639-1 codes (e.g., `en+pl`)
- Smart-skip logic: slash commands, trivial responses, short prompts, pure numbers, single characters
- Custom skip patterns via `skipPatterns` config
- Custom rewriting instructions via `customInstructions` config (max 500 chars)
- Three display modes: `silent`, `show-and-confirm` (manual only), `show-and-send`
- Fail-open design: config errors, parse failures, and missing dependencies never block prompts
- Configuration at `~/.claude/promptup.json` with validation and per-field fallback to defaults

[1.0.0]: https://github.com/zeglin/promptup/releases/tag/v1.0.0
