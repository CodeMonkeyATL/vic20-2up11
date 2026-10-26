# 2up11 todo

Known issues and ideas, found while bringing the repo's tooling in line with vic20-ringsort (2026-10-25). Nothing here is scheduled; pick what's worth doing.

## memory

- **27 bytes free** after quitting (measured with `?fre(0)`). Any new feature needs a tightening pass first.
- Tightening candidates:
  - the four move routines (1000, 1400, 1800, 2200) are near-copies of each other;
  - long variable names (`base`, `idx`, `full`) cost bytes on every use, and BASIC only reads the first two letters anyway;
  - `goto` after `then` is redundant (`thengoto1150` → `then1150`);
  - the spaces in `mt or 1` (lines 410-470, the 4 lint warnings);
  - `data` + `bx$()` for the border could become `{$xx}` codes in string literals (see the cheatsheet).

## docs

- **README:** says "There is no scoring system"; there is one now. "Deterministic and repeatable logic for testing" isn't true (the seed is `rnd(-ti)`).
- **design.md:**
  - "merge encoding" says the +65 flag doesn't change the tile's value; it does (+65, then -64 when drawn, is the step to the next power).
  - "game over" says execution ends; it doesn't, `n` starts a new game.
  - missing the variable table and routine map that `basic-guidelines.md` asks for.
  - doesn't describe the score yet.

## repo

- No release yet. When the game is finished, tag it `v1` and make a release with the PRG, like RingSort v2 (experimental builds get `v0.x`).
- No README screenshot of the title screen; the existing screenshots predate the score.

## ideas

- Deal or seed numbers (as in RingSort) to replay a game; probably doesn't fit in 27 bytes.
- A best score for the session.
