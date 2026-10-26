# 2up11 todo

Known issues and ideas, found while bringing the repo's tooling in line with vic20-ringsort (2026-10-25). Nothing here is scheduled; pick what's worth doing.

## memory

- **27 bytes free** after quitting (measured with `?fre(0)`). Any new feature needs a tightening pass first.
- Tightening candidates:
  - the four move routines (1000, 1400, 1800, 2200) are near-copies of each other;
  - long variable names (`base`, `idx`, `full`) cost bytes on every use, and BASIC only reads the first two letters anyway;
  - `goto` after `then` is redundant (`thengoto1150` → `then1150`);
  - the spaces in `mt or 1` (lines 410-470, the 4 lint warnings);
  - `data` + `bx$()` for the border could become `{$xx}` codes in string literals (see the cheatsheet);
  - `md` is set on every move key (lines 400-460) but never read;
  - `dimt(7)` reserves 8 elements, but only `t(0)`-`t(3)` are used; `dimt(3)` saves 20 bytes. It was sized for a planned user-selectable board up to 8x8; `w` had to stay at 3 for space. If a bigger board comes back (e.g. in an expanded-memory version), size it from `w` then.
- **`a=fre(0)` (line 300):** forces garbage collection on every loop pass. It was added early on, when screen drawing built a lot of strings; it may no longer be needed (`get a$` and the `chr$()`s in the border still leave some garbage). BASIC V2 can't call `fre(0)` as a bare statement, so if it stays, assign it to a temp variable that already exists (e.g. `x`, which 36000 sets fresh each time) so `a` doesn't take up a variable slot. Better still: measure whether it's needed at all, and if it is, call it only after a move instead of on every idle pass (see speed).

## speed

The game is playable but slow, almost painfully. Where the time likely goes (measure before and after with `ti`):

- **The idle loop (300-500):** every pass runs `fre(0)`, and while `mt` is non-zero it also calls 6000, which scans all 16 cells (37000). Every key is compared up to 12 times (`a$="w"` twice for each direction). Do the game-over check only after a failed move, and dispatch with `on … goto` or one test per key.
- **The move routines:** the compression loop repeats whole passes until nothing moves (up to 3 per line), and each step re-tests bounds (`d>w`, `d<0`) that the loop range already guarantees. A single pass that writes each tile to the next free cell does the same job.
- **Drawing (32000):** after every move, all 16 tiles are redrawn, each through `gosub900` (up to 5 `if`s) and two `poke`s with address arithmetic. Only changed cells need redrawing, and a lookup string (`asc(mid$(...))`) could replace 900's chain.
- **Variable order:** BASIC finds variables by searching them in creation order, so the hot loop variables (`t`, `c`, `r`, `mp`, `gt`) should be created first in line 100.
- **Exponent in the score:** `2^(sv+1)` is slow in BASIC V2; doubling a value or a small table would be faster (but costs bytes).

## sound

Sound effects, similar to RingSort's (see its `docs/design.md` sound table and the cheatsheet's sound section), as memory allows:

- **slide:** a short soft sweep when tiles move without merging;
- **merge:** a blip, maybe pitched by the merged power so bigger merges sound higher;
- **no move in that direction:** RingSort's cancel woosh;
- **2048 reached** (inverted `1`, power 11): RingSort's win chime;
- **game over:** a slow falling tone (suggestion).

Each sound needs bytes, so this comes after tightening. A shared sweep routine (like RingSort's 5000) keeps the cost per sound small.

## repo

- No release yet (`v0.9` tags the pre-cleanup state). When the game is finished, tag it `v1` and make a release with the PRG, like RingSort v2 (experimental builds get `v0.x`).
- No README screenshot of the title screen; the existing screenshots predate the score.

## ideas

- **Replayable games:** BASIC's random numbers are deterministic after a seed: `rnd(-n)` followed by `rnd(1)` calls always gives the same sequence (RingSort's deal numbers rely on this). Seeding with a game number instead of `ti` would make every game replayable: same number, same tile spawns for the same moves. Costs: showing the number, and a way to type one in. 2048 players don't expect it, so it's low priority; probably only in an expanded-memory version.
- A best score for the session.
