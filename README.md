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

The list of consumer repos — and which shared files each one receives — lives in
[`targets.tsv`](targets.tsv), which `sync-build-config.sh` reads at runtime. That
manifest is the single source of truth; this table mirrors it for humans.

- **AKABK-Brain** — all three files
- **AKABK-MCP** — all three files
- **AKABK-CLI** — `.editorconfig` only. Its `Directory.Build.props` is an
  *application* profile (single-file publishing, app metadata), not the shared
  *library* profile, so it keeps its own and only the lint config is synced.

The Node (Outlook, BrowserExtension, Stream-Deck) and Swift (TV) repos don't
share meaningful build config and are intentionally excluded. Project-specific
`CLAUDE.md` files stay in their own repos; cross-cutting rules live in
`~/.claude/CLAUDE.md`.

### The `targets.tsv` manifest

One target per line, TAB-separated: `<repo-dir><TAB><comma-separated files>`.
Blank lines and `#` comments are ignored. Paths are relative both to the repo
root and to `./config`. To onboard a new consumer or change which files it gets,
edit `targets.tsv` — no script change needed.

```
AKABK-Brain	Directory.Build.props,.editorconfig,GitVersion.yml
AKABK-MCP	Directory.Build.props,.editorconfig,GitVersion.yml
AKABK-CLI	.editorconfig
```

## Usage

```bash
# Propagate canonical config into every target repo
./sync-build-config.sh

# Report drift without changing anything (exit 1 if any target is out of sync)
./sync-build-config.sh --check

# Reverse-promote: pull a consumer's edited file(s) back into ./config
./sync-build-config.sh --from AKABK-MCP

# Show usage
./sync-build-config.sh --help
```

## Workflow

1. Edit the canonical file under `config/`.
2. Run `./sync-build-config.sh` to push it to the consuming repos.
3. Commit the change here **and** in each affected repo (they're separate repos).

Optionally wire `./sync-build-config.sh --check` into each consumer's CI so a
drifted copy fails the build.

### Promoting an ad-hoc edit (`--from`)

The normal push treats `./config` as canonical and **overwrites** the consumer
copies. If you (or a teammate) instead edited a synced file *directly* in a
consumer repo, the next sync would silently clobber that edit. To keep it, first
promote it back to canonical:

```bash
# Copy AKABK-MCP's edited synced file(s) back into ./config
./sync-build-config.sh --from AKABK-MCP
```

Only files that repo is declared to receive in `targets.tsv` are eligible, so
`--from` never promotes a file the repo isn't meant to own. After promoting,
review the diff in `config/`, run the normal `./sync-build-config.sh` to fan the
change out to the other consumers, then commit here and in each repo.

## Provenance convention

The files under `config/` are **canonical — do not edit the synced copies in the
consumer repos directly.** Change the canonical file here and push, or use
`--from` to promote an unavoidable local edit. (This convention is documented
here only; the synced files themselves carry no injected provenance header, so
they stay byte-for-byte identical across repos and the drift check stays exact.)
