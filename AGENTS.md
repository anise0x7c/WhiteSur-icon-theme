# AGENTS.md

Icon theme repo (macOS Big Sur style SVGs for Linux). No build system, tests, lint, or CI — the only code is `install.sh`, `release/make-release.sh`, and `scan-dead-links.sh`. Verification is manual.

## Commands

- Install (default `~/.local/share/icons`; as root `/usr/share/icons`): `./install.sh`
- Safe test install to a scratch dir: `./install.sh -d /tmp/opencode/icons-test`
- Uninstall: `./install.sh -r`
- Syntax-check after editing scripts: `bash -n install.sh`
- Check `links/` + `src/` symlinks (simulates install-time overlay; exit 1 on broken): `./scan-dead-links.sh`. `./scan-dead-links.sh -d DIR` does a plain dangling check on an installed theme.
- Requires `gtk-update-icon-cache` on PATH — `set -e` aborts the whole install without it.

## How install.sh works (non-obvious)

- Each variant is installed as a **triple**: `WhiteSur`, `WhiteSur-light`, `WhiteSur-dark`.
- Light/dark variants are generated at install time by **literal `sed` hex swaps** on the copied SVGs (`#f2f2f2`→`#363636` for light, `#363636`→`#dedede` for dark) plus relative symlinks into the base theme. Changing icon colors in `src/` can silently break variant generation.
- `-t/--theme` is multi-valued: it consumes following args until the next `-`/`--` flag.
- Budgie special-case keys off `$DESKTOP_SESSION == '/usr/share/xsessions/budgie-desktop'`.
- `index.theme` is copied from `src/index.theme` and the theme `Name`/dirs are rewritten via sed.

## Directory map

| Dir | Purpose | Used by install.sh |
|---|---|---|
| `src/` | Master icon source (base + light + dark assets) | yes |
| `links/` | Committed relative symlinks aliasing icon names (e.g. app-id → generic icon), copied over the install last | yes |
| `colors/color-<name>/` | Per-color-variant `places/scalable` overrides for `-t <name>` | yes |
| `bold/` | Bolder panel icons (`-b`) | yes |
| `alternative/` | Redesigned app/file-manager icons (`-a`) | yes |
| `plasma/` | KDE logo replacing Apple logo (`-p`) | yes |
| `templates/` | SVG templates for drawing new icons | no |
| `original/`, `bolder/` | Asset pools, not referenced by install.sh | no |
| `release/` | Output dir for `make-release.sh` | — |

## Conventions

- Symlinks in `links/` are relative and committed to git — keep them relative (they're resolved inside the user's install dir).
- Icon files are flat SVG; app icons live in `src/apps/scalable/` (~1400 files), aliased by symlinks rather than duplicated.
- Release: `release/make-release.sh` installs all variants into `release/`, tars them to `.tar.xz`, then deletes the installed dirs. Tarballs (`*.xz`) are gitignored.
