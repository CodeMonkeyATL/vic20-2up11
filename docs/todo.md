# 2up11 todo

Known issues and ideas, found while bringing the repo's tooling in line with vic20-ringsort (2026-10-25). Nothing here is scheduled; pick what's worth doing.

## memory

- **About 887 bytes free** after quitting, after the speed pass (it was 27 before the first tightening pass; see `docs/design.md`, "memory"). Plenty of room left.
- **`x=fre(0)` (line 310):** forces garbage collection once per key (it used to run on every idle pass, as `a=fre(0)`). It was added early on, when screen drawing built a lot of strings. Now almost nothing makes string garbage (only `get a$`), so it can probably go; check that no collection pause shows up in a long game without it.

## speed

The speed pass (2026-10-25) took a successful move from about 3.2 s to 1.7 s at worst; `docs/design.md` ("speed") has the measurements and what changed, and "testing" has the timing harness. Possible further gains, each small:

- **Exponent in the score:** `2^(p+1)` in 1020 is slow in BASIC V2 and runs once per merge; a table of powers of 2 (a float array, about 110 bytes) would be faster.
- **Dispatch:** each key is compared up to 8 times; most keys are moves, so test those first.
- **The move (1000):** every line is copied into `t%()` and scanned even when it can't change (35 jiffies for a move where nothing moves); a cheaper way to spot unchanged lines would help.

## repo

- No release yet (`v0.9` tags the pre-cleanup state). When the game is finished, tag it `v1` and make a release with the PRG, like RingSort v2 (experimental builds get `v0.x`).
- No README screenshot of the title screen; the existing screenshots predate the score.

## tooling

- **Automated testing:** there are no tests; changes are checked by eye in xvic, using the direct-mode test boards in `docs/design.md` ("testing"). The pieces for automation exist already: `keys.ps1` can set up a board and play moves, and the remote monitor can read screen RAM (`m 1e00 1ff9`) or the grid itself. A script could run a fixed sequence and compare the screen against a saved result. A fixed seed (see "Replayable games" below) would make tile spawns repeatable too.
- **Reusable components:** some routines are shared between games by copying: the sound sweep (600 here, 5000 in RingSort), and likely more to come (a PLOT locate, a key queue display). A small library of BASIC routines, each in a fixed line-number block, could be merged into a game at build time, since petcat has no include. This spans repos, so it ties in with the duplicated shared files (see the parent folder's `CLAUDE.md`).
- **Standard line numbers for common components:** give each shared routine the same line-number block in every game (for example, sound always at 600), so a routine copies or merges in unchanged and a `gosub` reads the same everywhere. Today the blocks differ (sound is 600 here and 5000 in RingSort). Needs a table of reserved blocks, probably in `docs/basic-guidelines.md`, and renumbering in the existing games.
- **Machine language routines:** explore ML for a banner/box/dialog routine and other strategic components, where BASIC is slow or bulky (drawing boxes and borders, filling color RAM, maybe the move itself). On an unexpanded VIC the question is where the code lives: the cassette buffer (828-1019, 192 bytes) needs no memory taken from BASIC, but loading it from `data` costs twice (see the guidelines); lowering the top of BASIC or appending the code to the PRG are the alternatives. Calls pass values through pokes or the 780-783 registers, as with PLOT.

## ideas

- **Replayable games:** BASIC's random numbers are deterministic after a seed: `rnd(-n)` followed by `rnd(1)` calls always gives the same sequence (RingSort's deal numbers rely on this). Seeding with a game number instead of `ti` would make every game replayable: same number, same tile spawns for the same moves. Costs: showing the number, and a way to type one in. 2048 players don't expect it, so it's low priority; probably only in an expanded-memory version.
- A best score for the session.
- **Game timer:** show how long the current game has taken. `ti` counts jiffies (1/60 s) and `ti$` gives `hhmmss`, so either store `ti` when the game starts or set `ti$="000000"` in 200. Open questions: where it goes on screen, whether it updates only after each move (cheap) or while waiting for a key (the wait loop would have to redraw it), and whether it stops at game over.
