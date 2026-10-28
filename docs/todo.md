# 2up11 todo

Known issues and ideas, found while bringing the repo's tooling in line with vic20-ringsort (2026-10-25). Nothing here is scheduled; pick what's worth doing.

## memory

- **About 470 bytes free** after quitting, after the mute toggle (582 after the screen layout and game timer, 887 after the speed pass; it was 27 before the first tightening pass; see `docs/design.md`, "memory"). Plenty of room left.
- **`x=fre(0)` (line 310):** forces garbage collection once per key (it used to run on every idle pass, as `a=fre(0)`). It was added early on, when screen drawing built a lot of strings. Now almost nothing makes string garbage (only `get a$`), so it can probably go; check that no collection pause shows up in a long game without it.

## speed

The speed pass (2026-10-25) took a successful move from about 3.2 s to 1.7 s at worst; `docs/design.md` ("speed") has the measurements and what changed, and "testing" has the timing harness. Possible further gains, each small:

- **Exponent in the score:** `2^(p+1)` in 1020 is slow in BASIC V2 and runs once per merge; a table of powers of 2 (a float array, about 110 bytes) would be faster.
- **Dispatch:** each key is compared up to 8 times; most keys are moves, so test those first.
- **Timer in the key wait:** 300 now calls 6100 on every idle pass, which slows the wait loop a little (a few milliseconds per pass). Not measured; only matters if key response ever feels sluggish.
- **The move (1000):** every line is copied into `t%()` and scanned even when it can't change (35 jiffies for a move where nothing moves); a cheaper way to spot unchanged lines would help.

## repo

- No release yet (`v0.9` tags the pre-cleanup state). When the game is finished, tag it `v1` and make a release with the PRG, like RingSort v2 (experimental builds get `v0.x`).
- No README screenshot of the title screen; the existing screenshots predate the score, the timer and the new layout (2026-10-26).

## tooling

- Cross-repo tooling plans (automated testing, reusable components, standard line numbers, machine language routines) moved to the private `meta` repo, `ideas.md`.

## ideas

- **Replayable games:** BASIC's random numbers are deterministic after a seed: `rnd(-n)` followed by `rnd(1)` calls always gives the same sequence (RingSort's deal numbers rely on this). Seeding with a game number instead of `ti` would make every game replayable: same number, same tile spawns for the same moves. Costs: showing the number, and a way to type one in. 2048 players don't expect it, so it's low priority; probably only in an expanded-memory version.
- A best score for the session.
