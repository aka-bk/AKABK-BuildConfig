# AKABK-BuildConfig

Canonical build and lint configuration shared across the .NET repos in the
AKA-BK suite. The repos stay independent — this is the single source of truth
for the config files they have in common, kept in sync by a script rather than
merged into a monorepo.

## What's shared

| File | Purpose |
|------|---------|
| `config/Directory.Build.props` | .NET library/service build profile — GitVersion wiring, assembly info, NU1903 suppression |
| `config/.editorconfig` | Formatting + C# style + StyleCop suppressions for .NET projects |
| `config/GitVersion.yml` | GitVersion configuration |

## Consumers

Defined in the `TARGETS` list in `sync-build-config.sh`:

- **AKABK-Brain** — all three files
- **AKABK-MCP** — all three files
- **AKABK-CLI** — opt-in (commented out). Its `Directory.Build.props` is an
  *application* profile (single-file publishing, app metadata), not the shared
  *library* profile, so only `.editorconfig` would be safe to sync. Uncomment
  the entry to include it.

The Node (Outlook, BrowserExtension, Stream-Deck) and Swift (TV) repos don't
share meaningful build config and are intentionally excluded. Project-specific
`CLAUDE.md` files stay in their own repos; cross-cutting rules live in
`~/.claude/CLAUDE.md`.

## Usage

```bash
# Propagate canonical config into every target repo
./sync-build-config.sh

# Report drift without changing anything (exit 1 if any target is out of sync)
./sync-build-config.sh --check
```

## Workflow

1. Edit the canonical file under `config/`.
2. Run `./sync-build-config.sh` to push it to the consuming repos.
3. Commit the change here **and** in each affected repo (they're separate repos).

Optionally wire `./sync-build-config.sh --check` into each consumer's CI so a
drifted copy fails the build.
