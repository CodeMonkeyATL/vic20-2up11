# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

2up11 ("2↑11" on the title screen), a 2048-style tile-merging puzzle for an **unexpanded VIC-20**, written in Commodore BASIC V2 (petcat text format). The 4x4 grid holds powers of two, shown as single characters: `1`-`9`, `0`, then reversed `1`-`9`, reversed `0`. The README has the rules and controls; `docs/design.md` explains how the program works. `docs/todo.md` lists known issues and ideas.

## Build and run

- **Build + run (what the IDE Build does):** `powershell -NoProfile -ExecutionPolicy Bypass -File buildtools/build-and-run.ps1 -BasFile src/<name>.bas`
  - Runs `petcat.exe -w2 -l 1001 -o prgs/<name> src/<name>.bas`, then autostarts the PRG in xvic. If xvic is already running, it's sent over the remote monitor (127.0.0.1:6510); otherwise xvic is started with `-memory none -keymap 0 -remotemonitor`.
  - `petcat.exe` and `xvic.exe` must be on PATH (VICE 3.10 GTK3). Copies of petcat/c1541 are also in `tools/`.
  - The local build is byte-identical to the CI build, so building locally leaves `prgs/2up11` unchanged unless the source changed. Don't commit locally built PRGs; CI builds them.
- **See the screen:** `powershell -NoProfile -ExecutionPolicy Bypass -File buildtools/screenshot.ps1` saves a PNG to `screenshots/temp/` (gitignored). The `/screenshot` skill wraps this. Pass `-OutFile` only as an absolute path.
- **Press keys:** `powershell -NoProfile -ExecutionPolicy Bypass -File buildtools/keys.ps1 -Keys "<keys>"` types into the running program through the monitor's `keybuf` command. `keybuf` types its argument literally; `\n` types Return and `\xNN` any character (`\x93` clears the screen). Example: after `q`, `-Keys "\x93?fre(0)\n"` prints free memory on a clean screen.
- **Remote monitor:** talk to xvic only through these scripts (`build-and-run.ps1` autostart, `screenshot.ps1`, `keys.ps1`). Never send `x`, and always read the reply before disconnecting; otherwise the remote monitor wedges. Send one command per connection: `keybuf` and `autostart` written together wedged it.
- **Autostart replays keys:** `autostart` into a running xvic types the last monitor `keybuf` string again right after `RUN`, which makes tests show moves that were never sent. `build-and-run.ps1` sets the string to a single `z` before autostarting; 2up11 ignores `z`. Real keypresses are never replayed.
- **Lint:** `buildtools/check-basic.ps1 -BasFile <file>` checks a source file against the guidelines: missing `goto`/`gosub`/`then` targets, lines over 88 characters as listed, spaces outside strings and `rem`s, and line numbers that are unnumbered, duplicated or out of order. `build-and-run.ps1` runs it before petcat; it only prints warnings and never stops the build. `2up11.bas` currently has 4 warnings (the spaces in `mt or 1` etc., lines 410-470).
- There are no tests. Verify changes by building and looking at the emulator screen.
- **IDE tasks:** the user works in Visual Studio (Open Folder). VS reads only `.vs/tasks.vs.json`, which is gitignored; `buildtools/tasks.vs.json` is the committed copy (and `buildtools/tasks.json` is the VS Code equivalent). Keep the copies in sync. Every VS Build prints a harmless "The system cannot find the file specified." that comes from VS itself, not the script.
- **CI:** `.github/workflows/build-prg.yml` runs petcat on changed `.bas` files when a PR is merged (or a `v*` tag is pushed) and commits the PRGs to `prgs/`. A filename suffix picks the petcat flags (`-vic20-8k.bas`, `-c64.bas`, …); plain names get `-w2 -l 1001`, the same as the local build.

## Source files (`src/`)

- `2up11.bas`: the game.

## Docs

- `docs/design.md`: how `2up11.bas` works. Keep it in sync with code changes.
- `docs/cheatsheet.md`: general VIC-20 reference (petcat tokens, colors, graphics glyphs, color and sound registers, sound patterns). It's shared with the other CodeMonkeyATL repos (copied from vic20-ringsort, where its test programs live), so keep it free of 2up11 specifics; those go in `design.md`.
- `docs/basic-guidelines.md`: the coding rules, also shared (included below).
- `docs/todo.md`: known issues and ideas; the user decides what gets done.

## Program architecture (`2up11.bas`)

Memory is the binding constraint: **27 bytes free** after quitting (measured 2026-10-25). Any feature needs bytes freed first; measure with `?fre(0)`, since estimates run low.

- **Flow:** 100 init (`w=3`, dims, seed `rnd(-ti)`, box characters 30000) → 200 new game (clear grid, score 0, full draw 5000, score 39000, spawn a tile 36500) → main loop 300-500: check game over (6000) when the last key didn't move anything, then `get` and dispatch `r` redraw, `%` debug dump of the grid, `n` new game, `q` quit, and `w`/`a`/`s`/`d` moves. A move that changed the board (`dm=1`) redraws the tiles (32000), spawns a tile (36500) and shows the score (39000).
- **Grid:** `gt(0..15)`, row-major 4x4. A cell holds the tile's power (1 = 2, 2 = 4, … up to 20), 0 = empty. Routine 900 maps a power `p` to its screen code `dp` (`1`-`9`, `0`, reversed `1`-`9`, reversed `0`).
- **Moves:** 1000 right, 1400 left, 1800 up, 2200 down. Each copies a row or column into the line buffer `t()`, merges equal neighbours (scanning from the side it moves toward, one merge per tile), slides the tiles over, writes the line back, and sets `dm=1` if anything moved or merged.
- **Merge flag:** a merged tile gets `+65` in the grid. The tile draw (32055) sees `p>64`, subtracts 64 and colors the tile (blue, color 6); so `+65` then `-64` is the increment to the next power, plus a one-draw highlight. Newly spawned tiles are stored with `+128` (129 or 130) and immediately reduced by 36510, which draws them in red.
- **Game over (6000):** `mt` collects a bit per direction that didn't move the board (w 1, a 2, s 4, d 8) and resets after a move that did. With the board full (37000) and `mt=15`, it prints "game over"; the program keeps running, and `n` starts a new game.
- **Score:** `ss`, raised by 39100 on each merge by `2^(sv+1)` (the merged tile's value, as in 2048), printed on row 3 by 39000.
- **Screen:** title 38000 (rows 0-6, with the key help), green box border 31000 from the `bx$()` characters (30000), tiles poked into screen RAM at `7923+t+r*22+c` with colour RAM at `+30720` (`t` is the border's tab offset).
- Subroutines live at fixed line-number blocks; keep new routines in their own blocks.

## Coding guidelines

Follow these for all BASIC written in this repo:

@docs/basic-guidelines.md

## petcat and xvic notes

- petcat auto-numbers unnumbered source lines (previous line + 2). So they end up in the PRG, and they need a numbering gap after the preceding line. Lowercase in the source becomes unshifted PETSCII (displayed as uppercase on the VIC).
- In xvic, `-keymap 0` (symbolic) makes PC keys type their printed symbols. Under the positional keymap, `=` is on Page Down.
