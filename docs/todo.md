# 2up11 todo

Known issues and ideas, found while bringing the repo's tooling in line with vic20-ringsort (2026-10-25). Nothing here is scheduled; pick what's worth doing.

## memory

- **About 1800 bytes free** after quitting, after the key queue (it was 27 before the first tightening pass; see `docs/design.md`, "memory"). Room for sound and more.
- **`x=fre(0)` (line 310):** forces garbage collection once per key (it used to run on every idle pass, as `a=fre(0)`). It was added early on, when screen drawing built a lot of strings. Now almost nothing makes string garbage (only `get a$`), so it can probably go; check that no collection pause shows up in a long game without it.

## speed

The game is playable but slow, almost painfully. The first tightening pass made it smaller but not faster: a move plus the redraw takes about 2 seconds (117 jiffies for a right move with no merges, 138 for an up move with 8 merges; v0.9 took 117 and 156). Measure each change with `ti`, e.g. after `q`: `a0=ti:b=3:l=4:s=-1:gosub1000:gosub32000:?ti-a0`.

Already done in the tightening pass: the idle loop waits on `get` alone (no `fre(0)` or game-over scan per pass), the game-over check runs only after a failed move, and sliding is a single pass.

Still to try:

- **Time the parts** first: 1000 (the move) vs 32000 (the redraw) on their own.
- **Drawing (32000):** after every move, all 16 tiles are redrawn through 900, which computes the address with `int()` and a multiply and the screen code with a 5-term formula. Only changed cells need redrawing (1000 knows which); or loop over rows and columns so the address is a running sum.
- **The move (1000):** every cell access computes `c+i*s`; a running index (add `s` each step) avoids the multiply. Lines that didn't change still get written back.
- **Variable order:** BASIC finds variables by searching them in creation order, so the hot loop variables (`i`, `j`, `p`, `c`, `s`, `mp`, `dm`) should be created first in line 100 (costs a few bytes).
- **Exponent in the score:** `2^(t%(i)+1)` is slow in BASIC V2; a small table or doubling would be faster (but costs bytes).
- **Dispatch:** each key is compared up to 8 times; most keys are moves, so test those first.

## sound

Sound effects, similar to RingSort's (see its `docs/design.md` sound table and the cheatsheet's sound section), as memory allows:

- **slide:** a short soft sweep when tiles move without merging;
- **merge:** a blip, maybe pitched by the merged power so bigger merges sound higher;
- **no move in that direction:** RingSort's cancel woosh;
- **2048 reached** (inverted `1`, power 11): RingSort's win chime;
- **game over:** a slow falling tone (suggestion).

Each sound needs bytes; with about 1800 free there is room now. A shared sweep routine (like RingSort's 5000) keeps the cost per sound small.

## naming

- Rename the one-letter direction variables to two-letter names that say what they are, as a family with a shared first letter (`basic-guidelines.md`). Today, set per key in 400-440:
  - `b`: the cell where line 0 starts, on the wall side (0, 0, 12, 3 for w, a, s, d)
  - `l`: step from one line's start to the next (1 for up/down, 4 for left/right)
  - `s`: step from one cell to the next along a line, away from the wall (4, 1, -4, -1)
  - `m`: the direction's bit for game over (1, 2, 4, 8)
- One option is a `d` family: `dc` (first cell), `dl` (line step), `ds` (cell step), `db` (bit). `dm` (board changed) already starts with `d`, so it might become `mv`. Check each name against keywords (`to`, `if`, `or`, `on`, `fn`, `go`, `st`, `ti`) before using it. Costs about 1 byte per use; the wall variables `wa`/`ws`/`wc` already follow the pattern.

## repo

- No release yet (`v0.9` tags the pre-cleanup state). When the game is finished, tag it `v1` and make a release with the PRG, like RingSort v2 (experimental builds get `v0.x`).
- No README screenshot of the title screen; the existing screenshots predate the score.

## ideas

- **Replayable games:** BASIC's random numbers are deterministic after a seed: `rnd(-n)` followed by `rnd(1)` calls always gives the same sequence (RingSort's deal numbers rely on this). Seeding with a game number instead of `ti` would make every game replayable: same number, same tile spawns for the same moves. Costs: showing the number, and a way to type one in. 2048 players don't expect it, so it's low priority; probably only in an expanded-memory version.
- A best score for the session.
