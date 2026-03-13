# PromptUp

**Your prompts, but better.** A Claude Code plugin that automatically rewrites your prompts to be clearer, more specific, and more effective — so Claude gives you better answers on the first try.

```
You type:    fix the bug where users cant login after password reset
PromptUp:    Fix the bug where users cannot log in after a password reset.
             Investigate the password reset flow, check whether the new
             password hash is stored correctly, and verify the login
             validation logic accepts the updated credentials.
```

No API keys. No external calls. No latency. Claude itself does the rewriting.

---

## Why PromptUp?

We've all been there — you type a quick, messy prompt and Claude gives you a reasonable but not quite right answer. You rephrase, clarify, add context, and try again. PromptUp eliminates that back-and-forth by improving your prompts *before* Claude responds.

- **Fixes typos and grammar** — `cant` becomes `cannot`, missing punctuation gets added
- **Adds specificity** — vague requests become actionable instructions
- **Structures complex asks** — multi-part requests get broken into clear, ordered steps
- **Respects your intent** — improves *how* you ask, never changes *what* you ask
- **Speaks your language** — detects English, Polish, Spanish, or any language automatically

## Installation

```bash
# From the Anthropic marketplace
/plugin install promptup

# Or from GitHub
/plugin marketplace add zeglin/promptup
/plugin install promptup
```

That's it. No API keys, no configuration files, no setup steps. `/pp` works immediately.

---

## Two Ways to Use It

### Manual Mode — `/pp`

Prefix any prompt with `/pp` to rewrite it on demand:

```
/pp add tests for the auth module, make sure edge cases are covered
```

Claude rewrites it and shows you what changed:

```
[PromptUp] Rewritten (medium):
> Add unit tests for the authentication module. Cover the following edge cases:
> login with expired credentials, password reset token reuse, concurrent session
> handling, and rate limiting after failed attempts. Use the existing test
> framework and follow the project's testing conventions.
```

Then Claude responds to the improved version. You get a better answer without lifting a finger.

### Always-On Mode

Enable it once, and every prompt you type gets improved automatically:

```
/pp-config enable
```

Now just type normally:

```
you:       refactor the database layer its getting messy
```
```
[PromptUp] Rewritten (medium):
> Refactor the database layer to improve code organization and maintainability.
> Identify repeated query patterns and extract them into reusable methods.
> Ensure the refactoring preserves all existing behavior and passes current tests.
```

Short, trivial responses like "yes", "ok", "continue", "looks good", and "lgtm" are automatically skipped — PromptUp only activates when there's something meaningful to improve.

To turn it off:

```
/pp-config disable
```

---

## Rewrite Levels

PromptUp offers three levels of rewriting. Choose the one that fits your workflow:

### Light

Minimal touch-ups. Fixes typos, grammar, and punctuation without changing structure.

```
/pp-config set level light
```

| You type | PromptUp rewrites |
|----------|-------------------|
| `fix the bug were users cant login` | `Fix the bug where users can't log in.` |
| `add a test for the new endpint` | `Add a test for the new endpoint.` |

Best for: developers who write clear prompts but want typo/grammar cleanup.

### Medium (default)

Adds specificity, removes ambiguity, and improves structure.

```
/pp-config set level medium
```

| You type | PromptUp rewrites |
|----------|-------------------|
| `refactor the auth code` | `Refactor the authentication code to improve readability and maintainability. Extract repeated logic into helper functions and ensure all existing tests continue to pass.` |
| `why is this slow` | `Identify the performance bottleneck in the current context. Profile the relevant code paths, check for unnecessary database queries or N+1 problems, and suggest specific optimizations.` |

Best for: most developers, most of the time.

### Deep

Considers your codebase context, adds technical constraints, and structures prompts as actionable instructions.

```
/pp-config set level deep
```

| You type | PromptUp rewrites |
|----------|-------------------|
| `add caching` | `Add caching to the most frequently called endpoints. Consider the current project structure, identify which responses are safe to cache, choose an appropriate caching strategy (in-memory vs Redis based on the existing stack), set reasonable TTLs, and add cache invalidation where data mutations occur. Include tests for cache hit/miss scenarios.` |

Best for: quick, vague prompts that need serious expansion; complex tasks where you want Claude to think through constraints.

---

## Language Support

PromptUp detects the language of each prompt automatically and rewrites in the same language. This is the default — no configuration needed.

```
you:       napraw ten bug z logowaniem po resecie hasla
PromptUp:  Napraw błąd z logowaniem po zresetowaniu hasła. Sprawdź przepływ
           resetowania hasła, zweryfikuj czy nowy hash jest poprawnie zapisywany
           i upewnij się, że logika walidacji logowania akceptuje zaktualizowane
           dane uwierzytelniające.
```

### Bilingual Mode

If you regularly switch between languages, tell PromptUp which ones you use:

```
/pp-config set language en+pl
```

PromptUp detects which of your specified languages each prompt is in and rewrites accordingly. If a prompt is ambiguous, it falls back to the first language listed.

### Fixed Language

Force all rewrites into a specific language:

```
/pp-config set language en
```

---

## Display Modes

Control how PromptUp shows you the rewritten prompt:

### `show-and-send` (default)

Shows the rewritten prompt, then immediately responds to it:

```
[PromptUp] Rewritten (medium):
> <improved prompt>

<Claude's response to the improved prompt>
```

### `show-and-confirm`

Shows the original and rewritten versions side by side and asks for approval before responding. Only available in manual `/pp` mode:

```
[PromptUp] Original:
> fix the auth bug

[PromptUp] Rewritten (medium):
> Fix the authentication bug. Investigate the login flow...

Send the rewritten version? (yes/no/edit)
```

### `silent`

Rewrites invisibly — Claude sees and responds to the improved prompt, but you don't see the rewrite:

```
/pp-config set mode silent
```

Best for: developers who trust PromptUp and don't need to see the changes.

---

## Smart Skip

PromptUp is smart about when *not* to rewrite. These prompts pass through untouched:

| Category | Examples |
|----------|----------|
| **Slash commands** | `/help`, `/pp-config`, `/commit` |
| **Trivial responses** | `yes`, `no`, `ok`, `sure`, `continue`, `lgtm`, `ship it` |
| **Single characters** | `y`, `n`, `k` |
| **Pure numbers** | `42`, `100`, `3` |
| **Short prompts** | Anything below the `minLength` threshold (default: 20 characters) |

You can also add your own skip patterns:

```
/pp-config set skipPatterns cheers,brb,bye
```

---

## Configuration

All settings live in `~/.claude/promptup.json`. Use `/pp-config` to manage them:

```
/pp-config                         # show current settings
/pp-config enable                  # turn on always-on mode
/pp-config disable                 # turn off always-on mode
/pp-config set <key> <value>       # change a setting
/pp-config reset                   # restore all defaults
```

### Settings Reference

| Setting | Default | Options | Description |
|---------|---------|---------|-------------|
| `enabled` | `false` | `true`, `false` | Always-on mode. `false` = manual `/pp` only. |
| `mode` | `show-and-send` | `silent`, `show-and-confirm`, `show-and-send` | How the rewrite is displayed. |
| `level` | `medium` | `light`, `medium`, `deep` | How aggressively prompts are rewritten. |
| `language` | `auto` | `auto`, ISO 639-1 code, `+`-joined codes | Language for rewrites. `auto` detects per-prompt. |
| `minLength` | `20` | Any non-negative integer | Minimum characters to trigger a rewrite. `0` disables. |
| `skipPatterns` | `[]` | Comma-separated phrases | Custom phrases to skip (case-insensitive, exact match). |
| `customInstructions` | `""` | Free text (max 500 chars) | Extra instructions appended to every rewrite. |

### Custom Instructions

Add persistent instructions that apply to every rewrite:

```
/pp-config set customInstructions "Use formal tone, prefer British English"
```

```
/pp-config set customInstructions "Always structure rewrites as numbered steps"
```

```
/pp-config set customInstructions "Keep rewrites concise, no more than 2 sentences"
```

---

## How It Works

PromptUp uses Claude Code's `UserPromptSubmit` hook system with a **context injection** architecture:

```
You type a prompt
        |
        v
   [Hook fires]
        |
        +-- Slash command?  --> pass through
        +-- Trivial/short?  --> pass through
        +-- Disabled?        --> pass through
        |
        v
   [Inject rewriting instructions as additionalContext]
        |
        v
   Claude sees: your original prompt + rewriting instructions
        |
        v
   Claude rewrites the prompt, shows [PromptUp] block, responds
```

**Key design decisions:**

- **No external API calls** — Claude itself does the rewriting using the current session model. This means zero latency overhead, zero cost beyond your existing session, and no API key required.
- **Fail-open** — If anything goes wrong (config error, parse failure, missing dependencies), your prompt passes through unchanged. PromptUp never blocks your work.
- **No prompt replacement** — Claude Code hooks can't modify prompts directly. Instead, PromptUp injects instructions as context, and Claude handles the rewriting inline. This is actually better — Claude has full conversation context when rewriting.

---

## Examples

### Quick bug fix
```
you:       fix the thing that breaks when you click save twice
PromptUp:  Fix the bug where clicking the save button twice causes an error.
           Investigate the save handler for missing debounce or idempotency
           logic, and ensure rapid successive clicks don't create duplicate
           records or trigger race conditions.
```

### Vague refactoring request
```
you:       clean up the api
PromptUp:  Clean up the API layer. Identify inconsistent naming conventions,
           remove unused endpoints, standardize error response formats, and
           ensure all endpoints follow RESTful conventions. Preserve backward
           compatibility for existing clients.
```

### Non-English prompt
```
you:       dodaj testy do modulu logowania
PromptUp:  Dodaj testy jednostkowe do modułu logowania. Pokryj scenariusze:
           poprawne logowanie, nieprawidłowe hasło, zablokowane konto, wygasła
           sesja i próba logowania z nieprawidłowym tokenem. Użyj istniejącego
           frameworka testowego w projekcie.
```

### Already good prompt
```
you:       Add a retry mechanism to the HTTP client with exponential backoff,
           max 3 retries, and a 30-second timeout. Include tests.
PromptUp:  [no rewrite — prompt sent unchanged]
```

---

## License

MIT — do whatever you want with it.

## Contributing

Issues and PRs welcome at [github.com/zeglin/promptup](https://github.com/zeglin/promptup).

## Author

Built by [Voy Zeglin](https://github.com/zeglin).
