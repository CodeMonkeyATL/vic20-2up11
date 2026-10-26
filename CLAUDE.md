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
- **Lint:** `buildtools/check-basic.ps1 -BasFile <file>` checks a source file against the guidelines: missing `goto`/`gosub`/`then` targets, lines over 88 characters as listed, spaces outside strings and `rem`s, and line numbers that are unnumbered, duplicated or out of order. `build-and-run.ps1` runs it before petcat; it only prints warnings and never stops the build. `2up11.bas` should stay at 0 warnings.
- There are no automated tests. Verify changes by building and looking at the emulator screen; `docs/design.md` ("testing") has direct-mode lines that set up test boards (many merges with a 2048, a stuck board, every tile character, the move routine alone).
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

The source is tightened: no `rem`s, statements joined. The full explanation, including the variable table, is in `docs/design.md`; keep it in sync with code changes. The untightened original is tagged `v0.9`. Free memory after quitting is about **887 bytes** (2026-10-25, after the speed pass; it was 27 before the first tightening pass); `docs/design.md` has the history. Measure with `?fre(0)`, since estimates run low.

- **Flow:** 100-120 init (hot variables first, dims, seed `rnd(-ti)`, volume 15, the `sa%`/`cd%` tables) → 200 new game (clear grid, score 0, `mt` 0, full draw 5000, spawn a tile 36500) → main loop 300-480: wait for a key, `x=fre(0)` (forces garbage collection once per key), dispatch `r` redraw (resets `mt`), `%` debug dump of the grid, `n` new game, `q` quit, and `w`/`a`/`s`/`d` (400-440 set the direction and its wall; 450 colors the wall blue, shows the key queue (965), turns the tiles black (1100) and runs the move, which draws the lines that changed). A move that changed the board (`mv=1`, 455-460) turns its wall green (all four only if some were red), plays the move sound, spawns a tile (36500) and shows the score (39000); one that didn't colors its wall red and adds its bit to `mt` (465).
- **Grid:** `gt%(0..15)`, row-major 4x4, fixed size (loops run `0to3`/`0to15`). A cell holds the tile's power (1 = 2, 2 = 4, … up to 20), 0 = empty; never a flag. `cd%(p)` (line 120) is the screen code of each power (`1`-`9`, `0`, reversed `1`-`9`, reversed `0`), `sa%(x)` (line 110) the screen address of each cell.
- **Moves (1000-1070):** one routine for all four directions. `dc` (first cell of line 0), `dl` (step per line) and `ds` (step per cell, walking away from the wall) describe the direction; cell `i` of line `r` is `gt%(dc+r*dl+i*ds)`. Each line is copied into `t%(0..3)` wall side first, then merged and slid in one pass (`j` next free position, `lv` last tile that can still merge; `lv=0` after a merge allows one merge per tile), then cleared from `j`. Only if the line changed (`lm`) is it written back and drawn (1055-1065, skipping cells that didn't change). `mv=1` if any line changed.
- **Merge flag:** a merged tile gets `+65` in `t%()`. The write-back sees `p>64`, subtracts 64 and draws the tile blue (color 6); so `+65` then `-64` is the increment to the next power, plus a highlight. A new tile is drawn red. 1100 turns all 16 tile colors black at the start of each move, clearing last move's highlights.
- **Game over (470):** `mt` collects a bit per direction that didn't move the board (`db`: w 1, a 2, s 4, d 8) and resets after a move that did. `mt=15` can only happen on a full board with no merges, so it prints "game over" right-justified on the score row (`{home}`, 4 `{down}`s, 9 `{left}`s: `{left}` at column 0 wraps to the row above; not `tab`, since the title rows are linked into one logical line); the program keeps running, and `n` starts a new game.
- **Wall colors (950/960):** the four inner-wall glyphs on the side the tiles move toward are poked in color RAM: blue while the move runs, then green (the border color) if the board changed or red if it didn't. Red stays until a move changes the board, so the red walls are the `mt` bits; at game over all four are red. `wa`/`ws` (first glyph's color RAM address, step) are set per direction in 400-440, `wc` is the color. A redraw or new game reprints the border green and resets `mt`.
- **Key queue (965-985):** peeks the KERNAL keyboard buffer (`peek(198)` keys at 631-640) without taking keys, and pokes them as screen codes (`and63`) on row 18 under the board (screen 8083, 10 cells). 965 puts the active key `a$` first in green (`o=1`); `gosub970` (`o=0`) turns the first cell blue and shows only the waiting keys. It redraws only the cells in use (`ql` = end of what was shown last); 5000 sets the cells' blue color once and resets `ql`. 965 at move start and after the move; 970 once the move is complete, so the green key leaves only then.
- **Sound (600-670):** sweep routine 600 (`v`, `f`, `e`, `s`; same as RingSort's 5000). After a move (460 → 620): if nothing merged, a quiet slide (630, volume 5); otherwise one coin ding per merge (640-650: two quick notes on the high voice, pitch rising with the new power), from `mz%(0..mn-1)`, which 1030 fills as merges happen. A merge that makes 2048 or bigger (`p>10`) adds RingSort's win chime (610). No move: noise woosh (660, from 465). Game over: falling low tone (670). Volume 15 at start, 0 on quit. Claude can't hear xvic; the user tunes by ear (values in `docs/design.md`).
- **Score:** `ss`, raised on each merge by `2^(p+1)` (the merged tile's value, as in 2048), printed on the `score:` row by 39000.
- **Speed:** a successful move takes about 1.7 s at worst (was 3.2 s). Keep hot variables early in line 100, use the tables and `co` instead of formulas and long literals, and draw only what changed. `docs/design.md` ("speed", "testing") has the measurements and a one-line timing harness; time with `ti` on the same line as the work.
- **Screen:** title 38000 (with the key help), green double border 31000 (8x8 at `tab(7)`, rows 9-16, box glyphs as `{$xx}` literals), tiles poked into screen RAM at `sa%(x)` (`7931+x+18*int(x/4)`: rows 11-14, columns 9-12) with color RAM at `+co` (30720). 900 draws one tile (full redraw 32000, new tile); a move draws its changed lines itself.
- Subroutines live at fixed line-number blocks; keep new routines in their own blocks.

## Coding guidelines

Follow these for all BASIC written in this repo:

@docs/basic-guidelines.md

## petcat and xvic notes

- petcat auto-numbers unnumbered source lines (previous line + 2). So they end up in the PRG, and they need a numbering gap after the preceding line. Lowercase in the source becomes unshifted PETSCII (displayed as uppercase on the VIC).
- In xvic, `-keymap 0` (symbolic) makes PC keys type their printed symbols. Under the positional keymap, `=` is on Page Down.
