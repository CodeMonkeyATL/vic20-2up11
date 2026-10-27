# 2up11 design notes

2up11 is a VIC-20 BASIC V2 puzzle game inspired by 2048, adapted for a 4x4 grid and the constraints of an unexpanded VIC-20. Tiles represent **powers of 2**, not numeric values. The display uses PETSCII screen codes that progress through the VIC-20 character set in a predictable sequence.

This document describes the internal mechanics of the game, including tile encoding, movement, merging, random tile placement, scoring, game over detection and screen rendering. The routine map, variable table and memory history are at the end.

The source is tightened: no `rem`s, statements joined, one- and two-letter names. This document is where the explanations live. The untightened version is tagged `v0.9`.

## grid model

The game uses a fixed 4x4 grid, represented as a 1-dimensional integer array:

```
gt%(0) to gt%(15)
```

The grid is stored row-major:

```
row 0: gt%(0)  gt%(1)  gt%(2)  gt%(3)
row 1: gt%(4)  gt%(5)  gt%(6)  gt%(7)
row 2: gt%(8)  gt%(9)  gt%(10) gt%(11)
row 3: gt%(12) gt%(13) gt%(14) gt%(15)
```

The size is fixed at 4x4 in the code (loops run `0to3` and `0to15`). An earlier plan allowed a user-selectable board up to 8x8, sized by a variable `w`; that was dropped for memory.

## tile encoding

Each cell stores the tile's **power of 2**: 1 means 2, 2 means 4, 11 means 2048, and 0 means empty. Line 120 fills the table `cd%(0..20)` with the screen code for each power once at startup, using:

```
48 + p - 10*int(p/10) - 128*(p>10) + 16*(p=0)
```

| power `p` | shown as | screen code |
|---|---|---|
| 0 | blank | 32 |
| 1–9 | `1`–`9` | `p+48` |
| 10 | `0` | 48 |
| 11–19 | reversed `1`–`9` | `p+166` |
| 20 | reversed `0` | 176 |

`48 + p mod 10` is the digit, `p>10` is -1 for powers 11 and up and adds 128 (reverse video), and `p=0` is -1 for an empty cell and turns 48 into 32 (space). So the display is the last digit of the power, and reverse video marks powers 11 and up.

Inside the move routine, a merged tile carries `+65` until its line is written back (see below); powers never exceed 20, so anything over 64 is a flagged tile. The grid itself only ever holds true powers.

## movement

All four directions use one routine, 1000. The grid is treated as four **lines** (rows for left/right, columns for up/down), and each line is read starting from the side the tiles move toward. Three variables, set by the key dispatch (400–440), describe the direction:

- `dc` (direction, first cell): the cell where line 0 starts (its cell nearest the wall)
- `dl` (direction, line step): how far the start moves from one line to the next
- `ds` (direction, cell step): how far a cell is from the previous one along a line, walking away from the wall

| key | direction | `dc` | `dl` | `ds` | `db` |
|---|---|---|---|---|---|
| `w` | up | 0 | 1 | 4 | 1 |
| `a` | left | 0 | 4 | 1 | 2 |
| `s` | down | 12 | 1 | -4 | 4 |
| `d` | right | 3 | 4 | -1 | 8 |

Cell `i` of line `r` is `gt%(dc+r*dl+i*ds)`, so position 0 of the line buffer is always the cell against the wall. For each line, 1000:

1. copies the line into `t%(0..3)` (line 1000; `c` is the line's first cell, `x` walks the cells by adding `ds`)
2. merges and slides in one pass (1010–1040)
3. if the line changed (`lm=1`), writes it back and draws it (1055–1065); an unchanged line is skipped entirely

and sets `mv=1` if any line changed. `db` is the direction's bit for game over detection.

### merging and sliding: one pass

The standard 2048 single pass, with `j` the next free position from the wall and `lv` the value of the last tile placed that can still merge (0 = none):

```
for each tile p = t%(i), wall side first (empty cells are skipped):
  if p = lv:  t%(j-1) = p+65   merge into the tile placed before; lv = 0
  else:       t%(j) = p        place it; lv = p; j = j+1
then t%(j..3) = 0
```

Because `j` never passes `i`, writing `t%(j)` never overwrites a tile not yet read. Setting `lv=0` after a merge is what stops a merged tile from merging again in the same move, matching 2048's behavior: [2,2,2,·] becomes [4,2,·,·], not [4,·,·,·] or [2,4,·,·]. The clearing loop `fori=jto3` runs once even when `j=4`, which is why `t%()` has a fifth element `t%(4)`.

A merge (1020) also adds the merged tile's value to the score (`ss=ss+2^(p+1)`) and records the new power in `mz%(mn)`, counting merges in `mn` (reset to 0 by 1000). A move has at most 8 merges (2 per line), so `mz%(7)` is enough; the sound routine plays one ding per entry (see "sound"). `lm` is set by a merge, or by a tile placed closer to the wall than it was (`j<i` before advancing, tested as `j<=i` after).

This replaced a merge scan followed by a separate slide pass (see "speed").

## merge flag and visual feedback

A merged tile gets **65** added in the line buffer. When the line is written back (1055), the flag is stripped and the tile is drawn in blue:

```
p = t%(i) : sc = 0 : if p > 64 then sc = 6 : p = p - 64
```

So:

- `+65` then `-64` leaves the tile at its old power **+1**: this is the step up to the next power, the actual merge
- the tile is drawn in **blue** (color 6), so the player sees which tiles merged
- every other tile is drawn in black (color 0)

The blue (and the red of a new tile) lasts until the next move: 1100 turns the color RAM of all 16 tile cells black at the start of every move, before the move redraws only what changed.

## random tile placement

At the start of a game and after any successful move, 36500:

1. picks a random cell `x` until it finds an empty one
2. picks the power: 1 (a "2") 90% of the time, else 2 (a "4"): `p=1-(rnd(1)>=.9)`
3. stores it and draws it in **red** (color 2), so the player sees where it appeared

36500 is only called when at least one cell is empty (after a successful move, or on an empty board), so the search always ends.

The seed is `rnd(-ti)` at startup, so every run deals differently.

## scoring

`ss` is the score. Each merge adds the merged tile's value, `2^(p+1)` for two tiles of power `p` (two 4s make an 8 and score 8), as in 2048. 39000 prints it on the `score:` row after every successful move; a full redraw prints it with the title (38000). A new game resets `ss` to 0. The score has row 3 to itself, so it can grow to 15 digits (more than BASIC prints before switching to exponent notation).

## game over detection

The game doesn't search for possible merges. Instead, `mt` records which directions the player has tried without anything moving, one bit each (`db`: w 1, a 2, s 4, d 8). A move that changes the board resets `mt` to 0; a move that doesn't adds its bit (470, `mt=dbormt`). A new game or a redraw also resets `mt`.

When `mt=15`, all four directions have failed. That can only happen on a full board with no merges left (with an empty cell, some tile can always slide into it), so 470 goes on to 475 (otherwise back to 300), which updates the timer one last time (6100), stops it (`tg=1`), prints "game over!" and resets `mt`. The text is reverse red on row 17, halfway between the board (ends on row 14) and the key help (starts on row 20), just under the key queue. It covers columns 6–15, one past the border on each side: 10 characters, since 9 can't center under the 8-wide border. It gets there with `{home}`, 17 `{down}`s and `tab(6)`, which works because row 17 starts its own logical line; the cursor can't be relied on, since a redraw leaves it on row 21 and a score print on row 4. The program keeps running: `n` starts a new game, `q` quits. A redraw after game over clears the text, but the timer stays stopped.

## move indicator (wall colors)

The four inner-wall glyphs on the side the tiles move toward show what a move did:

| when | color |
|---|---|
| while the move runs | blue (6) |
| the move changed the board | green (5), the border color |
| nothing moved | red (2), until a move changes the board |

The red sides are exactly the bits in `mt`, so at game over all four inner walls are red, showing that every direction was tried. There's no "invalid move" text; the red wall says it.

The colors are poked into color RAM; the glyphs don't change. 400–440 set the wall for the direction along with `dc`, `dl`, `ds`, `db`:

| key | wall | `wa` (color RAM of the first glyph) | `ws` (step) |
|---|---|---|---|
| `w` | top, row 8, columns 9–12 | 38585 | 1 |
| `a` | left, column 8, rows 9–12 | 38606 | 22 |
| `s` | bottom, row 13, columns 9–12 | 38695 | 1 |
| `d` | right, column 13, rows 9–12 | 38611 | 22 |

450 colors the wall blue (950 with `wc=6`) and runs the move. A move that changed the board goes to 455, which colors that wall green (950 with `wc=5`) and, only if some walls are red (`mt` non-zero), all four (960). Otherwise 465 colors the wall red (950 with `wc=2`).

A redraw (`r`) or a new game reprints the whole border in green and resets `mt`, so the screen and the game over check agree: the player tries the dead-end directions again to rediscover them. The score is unaffected.

## screen rendering

| routine | draws |
|---|---|
| 5000–5010 | full redraw: title, score and `time` label (38000), the timer's digits (6130), border (31000), key help (38100), tiles (32000), queue colors. The top row comes first, so score and time show up together, before the slow board drawing |
| 32000 | all 16 tiles (only on a full redraw) |
| 1055–1065 | the tiles of a line that changed, as the move writes it back |
| 900 | one tile: cell `x`, power `p`, color `sc` (32000 and the new tile) |
| 1100 | all 16 tile cells' color back to black, at the start of each move |
| 39000 | the score |
| 6100–6130 | the timer's digits, when the second changes (see "game timer") |

### screen layout

```
row  0     blue bar
row  1     2↑11 BY CODEMONKEYATL          title (38000)
row  2     blue bar
row  3     SCORE: 1234                    score (38000; 39000 reprints it)
row  4     TIME:  12:34                   time label (38000), digits (6130), values aligned at column 7
rows 7-14  border, columns 7-14           31000; tiles on rows 9-12, columns 9-12
row 16     key queue, columns 7-16        965-985
row 17           GAME OVER!               only at game over (475)
rows 20-21 WASD=MOVE N=NEW GAME           key help (38100), second column at 11
           R=REDRAW  Q=QUIT
```

Rows 0–3 are one logical line: row 2 is printed full, so the cursor wraps into row 3 and links it. That's why 39000 reaches the score row with `{home}` and `{down}`s, and why 38000 prints the score right after the bar. Row 4 starts a new logical line; 38000 prints the `time:` label there, and its return leaves the cursor on row 5. The key help is printed after the border, with 5 `{down}`s from row 15. Row 22 is left blank, so nothing scrolls.

### border drawing

31000 prints a double box in green, 8×8 characters at `tab(7)` (columns 7–14, centered on the 22-column screen), rows 7–14. It uses the square box glyphs and the horizontal line as `{$xx}` codes in string literals:

```
row  7   b0 60 b2 b2 b2 b2 60 ae     outer top
row  8   7d b0 b1 b1 b1 b1 ae 7d     inner top
rows 9-12  ab b3 .. .. .. .. ab b3   sides; the 4x4 tiles go in the gap
row 13   7d ad b2 b2 b2 b2 bd 7d     inner bottom
row 14   ad 60 b1 b1 b1 b1 60 bd     outer bottom
```

┌ `b0`, ┐ `ae`, └ `ad`, ┘ `bd`, ─ `60`, │ `7d`, tees `b1`/`b2`/`b3`/`ab`. The tees of the outer and inner boxes face each other, so each grid row and column gets a rung between the two walls. The first `print` starts with 2 `{down}`s: 38000 leaves the cursor on row 5, so the border starts on row 7 and the tiles are on rows 9–12. The "inner wall" is the four tee glyphs beside each side of the grid (row 8, row 13, column 8 and column 13 next to the tiles).

### tile drawing

Tiles are poked straight into screen memory, inside the border. Two tables, filled once at startup, avoid recomputing anything per tile:

- `sa%(x)` (line 110): the screen address of cell `x`, `7887 + x + 18*int(x/4)`. That's screen memory (7680) + row 9 × 22 + column 9, plus 22 per grid row and 1 per column: `x + 18*int(x/4)` is `row*22 + col` for `x = row*4 + col`.
- `cd%(p)` (line 120): the screen code for power `p` (see "tile encoding").

The color goes to the address + 30720 in color RAM (the variable `co`, so the 5-digit number isn't parsed on every poke). Within a changed line, 1060 skips a cell whose power didn't change and that didn't just merge: 1100 already turned it black, and its character is still right.

Tile colors: black for a settled tile, blue for a tile that just merged, red for the tile that just appeared.

## sound

**How the VIC makes sound:** three square-wave voices, low (36874), middle (36875) and high (36876), plus noise (36877). A voice plays while its register holds 128–255 (higher = higher pitch) and is silent at 0. 36878 is the volume (0–15) for all of them. Line 105 sets the volume to 15 and quitting (340) sets it to 0, so no note is left playing. There are no envelopes or timers: each sound is a BASIC loop, and the game waits while it runs.

**Sweep routine (600):** `fori=ftoesteps:pokev,i:next:pokev,0:poke36878,15:return` steps register `v` from `f` to `e` by `s`, turns it off, and restores the volume (so a volume fade needs no restore of its own). Same as RingSort's 5000.

**Where each sound plays:** the move sounds play right after the move (460 calls 620), before the new tile and the score. The merge dings play back to back in an even rhythm, one per merge, so 3 merges sound different from 4 even though the redraw is slow.

**Tuning:** Claude can't hear xvic, so the values were tuned by the user's ear (the slide and merge sounds were redone once: the first slide was too loud and the first merge sound was a single chirp). A smaller `s` (fractions work, since `poke` drops them) makes a sweep longer and smoother.

| Sound | Line | Voice | Values |
|---|---|---|---|
| slide (tiles moved, nothing merged) | 630 | middle 36875 | at volume 5 (600 restores 15): `f=215`, `e=205`, `s=-2`, a short quiet fall |
| merge, one "coin ding" per merge | 640–650 | high 36876 | for each power `p` in `mz%(0..mn-1)`: note `n=190+3*p` (193 for a 2, 223 for a 2048) held by a 12-step delay loop, then `64+.75*n` (about a fourth higher: the period `256-n` shrinks to ¾) held by 40 steps, then off |
| 2048 or more made (`p>10`) | 610 | high 36876 | RingSort's win chime right after that merge's ding: notes `195+i*12` for `i`=1–4, each held by a 99-step delay loop |
| no move | 660 | noise 36877 at 250 | RingSort's cancel woosh: sweeps the **volume** from 15 to 0 by -1; 600 restores it, then 660 turns the noise off |
| game over | 670 | low 36874 | `f=200`, `e=140`, `s=-.5` (a slow falling tone), after the no-move woosh of the fourth failed direction |

620 picks the move sound: no merges (`mn=0`) → slide, otherwise the dings (640–650 loop over `k`; `for` always runs once, so 620 must skip it when `mn=0`).

## key queue

Keys pressed during a move wait in the KERNAL keyboard buffer (count at 198, keys at 631–640). Row 16 under the board, columns 7–16 (screen 8039, color RAM 38759), shows them: the key being worked on in **green** in the first cell, then the waiting keys in blue, oldest first.

```
965 poke8039,asc(a$)and63:poke38759,5:o=1:goto975
970 poke38759,6
975 q=peek(198)+o:qe=q:ifql>qethenqe=ql
980 ql=q:fori=otoqe-1:c=32:ifi<qthenc=peek(631+i-o)and63
985 poke8039+i,c:next:o=0:return
```

965 puts the active key (`a$`, already taken by `get`) in the first cell in green and sets the offset `o=1`, so the waiting keys start in the second cell. Called as `gosub970` (with `o=0`, which 985 restores), the first cell turns blue again and the waiting keys start there. `and63` turns a PETSCII letter (65–90) into its screen code (1–26); digits and space are the same in both. It only peeks, so the keys stay queued for `get`.

**Only the cells in use are redrawn:** `q` is the end of what's shown now, `ql` the end of what was shown last time, and the loop runs up to the larger of the two (`qe`), so it covers new keys and blanks the ones that left. Usually that's 1 or 2 cells instead of 10. The blue color of cells 2–10 is set once by 5000 (after the screen clear), which also resets `ql`. (`for` runs once even when `qe` is below `o`; that pokes a space into an already-blank cell, which is harmless.)

| when | call | shows |
|---|---|---|
| a move starts (450) | 965 | the active key, then the waiting keys |
| the move is done (460, before the sound, new tile and score) | 965 | the same, plus keys typed during the move |
| the move is complete (end of 460, or 465 for a move that changed nothing) | 970 | only the waiting keys: the active key leaves the queue |
| a key that isn't handled is taken (430) | 970 | the keys still waiting, so an ignored key leaves the queue at once |

So the leftmost green key is always the move in progress, and it only disappears once that move is completely done.

## control loop

```
300–480
```

300 waits for a key, updating the timer (6100) on every pass without one. 310 forces a garbage collection (`x=fre(0)`, see "memory") and then dispatches:

- redraw: r  
- debug dump: % (prints each cell's index and power)  
- new game: n  
- quit: q  
- movement keys: w, a, s, d (400–440 set the direction and its wall, 450 colors the wall blue, shows the key queue (965), turns the tiles black (1100) and runs the move, which draws the lines that changed)

After a move that changed the board (`mv=1`, lines 455–460):

- the wall turns green (950), and all four if some were red (960)
- the key queue is shown again (965), with any keys pressed during the move
- the move sound plays (620): the quiet slide, or a coin ding per merge (and the 2048 chime)
- a new tile is spawned (36500)
- the score is shown (39000)
- the active key leaves the queue (970)

Otherwise 465 colors the wall red, takes the active key off the queue (970), records the failed direction and plays the no-move woosh (660), and 470 checks for game over (475: timer stopped, the text, the game over tone 670).

## title and key help

38000 clears the screen and prints the title bar (reverse blue, `2↑11` in red), then the score on row 3 and the reversed `time:` label with a placeholder `00:00` on row 4 (see "screen layout"). After moves, 39000 reprints just the score. 38100, called after the border, prints the key help on rows 20–21: keys in red, their meaning in blue, the second column at column 11 (column 12 counting from 1).

## game timer

The timer shows the minutes and seconds since the game started, as `mm:ss` on row 4, columns 7–11, under the score's digits (`time:` label at 0–4). It's RingSort's timer (6000–6200 there), adapted:

```
6000 fori=1to2:c=int(w/10):pokey,48+w-10*c:w=c:y=y-1:next:return
6100 iftgthenreturn
6110 w=int((ti-tb)/60):ifw<0orw>5999thenw=5999:tg=1
6120 ifw=tethenreturn
6130 te=w:y=7779:j=int(w/60):w=w-60*j:gosub6000:w=j:y=y-1:goto6000
```

- **Start:** 200 sets `tb=ti` (jiffies at the start of the game), `te=0` and `tg=0`.
- **Ticking:** the key wait (300) calls 6100 on every pass without a key. 6120 returns unless the second has changed, so most calls only compute `w`. During a move nothing calls it, so the display catches up after the move; the elapsed time is still right, since it comes from `ti`.
- **Drawing:** 6130 pokes the seconds, skips the colon, then the minutes, right to left from column 11 (screen 7779). 6000 writes `w` as two digits at `y` going left. Their color is the blue the placeholder `00:00` was printed in.
- **Stopping:** at game over (475) the timer is updated once more and frozen with `tg=1`. It also freezes at 99:59 (`w>5999`), or if `ti` wraps at midnight (`w<0`).
- **Redraw:** 5000 draws the stored time with `w=te:gosub6130` right after the top row, so a redraw shows the right time even when the timer is frozen, and a new game shows `00:00`.

## testing

There are no automated tests. Changes are checked by playing in xvic, and by setting up boards from the BASIC prompt: quit with `q` (the variables survive), set cells of `gt%()`, then `gosub5000:goto300` redraws everything and continues the game loop with that board. Values are powers: 1 = 2, 10 = 1024, 11 = 2048. With Claude, `buildtools/keys.ps1` types the lines and `buildtools/screenshot.ps1` captures the result.

Rules for typing at the prompt:
- **Keep each line under 88 characters.** Longer direct-mode lines get mangled and can corrupt the BASIC session (it then needs a reset).
- **`data` doesn't work in direct mode** (`read` finds nothing: `?OUT OF DATA`), so set cells with assignments.
- A redraw (`r`) or new game (`n`) resets `mt`, the record of failed directions.

**Many merges, including 2048** (press `a`: seven coin dings rising in pitch, the 2048 chime after the last, then 4, 8 / 16, 32 / 64, 128 / 2048 and a score of 2300):

```
gt%(0)=1:gt%(1)=1:gt%(2)=2:gt%(3)=2
gt%(4)=3:gt%(5)=3:gt%(6)=4:gt%(7)=4
gt%(8)=5:gt%(9)=5:gt%(10)=6:gt%(11)=6
gt%(12)=10:gt%(13)=10:gt%(14)=0:gt%(15)=0
mt=0:ss=0:gosub5000:goto300
```

Set pairs to 0 to hear fewer dings (e.g. 3 vs 4 merges).

**Stuck board, for game over** (a checkerboard of 2s and 4s; press `w`, `a`, `s`, `d`: each inner wall turns red with the woosh, and the fourth brings GAME OVER and the falling tone):

```
fori=0to15:gt%(i)=1+((i+int(i/4))and1):next
mt=0:gosub5000:goto300
```

**Every tile character** (powers 5–20: `5`–`9`, `0`, reversed `1`–`9`, reversed `0`):

```
fori=0to15:gt%(i)=i+5:next:gosub5000:goto300
```

**The move routine on its own** (no sound, new tile or score display; set a direction, call 1000, print the cells, `mv` and the score). 1000 also draws the lines that change, so clear the screen before printing:

```
fori=0to15:gt%(i)=0:next:ss=0
gt%(0)=1:gt%(1)=1:gt%(2)=2:gt%(3)=2
dc=3:dl=4:ds=-1:gosub1000
?chr$(147);:fori=0to3:?gt%(i);:next:?mv;ss;mn
```

This moves row 0 right and prints `0 0 2 3 1 12 2`: two merges (powers 1→2 and 2→3), something moved, score 4+8, 2 merges. The direction values for `w`, `a`, `s`, `d` are in the "movement" table.

**Timing a move** (in jiffies, 1/60 s; see "speed"). This runs the same routines as a successful `d` move on a board where every line slides:

```
a$="d":dc=3:dl=4:ds=-1:wa=38611:ws=22:wc=6
fori=0to15:gt%(i)=(i*5+1)and3:next:gosub5000
t0=ti:gosub950:gosub965:gosub1100:gosub1000:wc=5:gosub950:t1=ti
t2=ti:gosub965:gosub620:gosub36500:gosub39000:gosub970:t3=ti
?chr$(147)t1-t0+t3-t2
```

Keep the timing on the same line as the work: timing across lines also counts the seconds spent typing.

**Free memory:** quit, then `?fre(0)` on a cleared screen. Play a few moves first so the game's variables exist, and measure on a fresh run: variables typed at the prompt (like `t0`) take memory too.

## routine map

| line | routine |
|---|---|
| 100–120 | init: hot variables first, dims, seed, volume 15, the `sa%` and `cd%` tables |
| 200 | new game: clear the grid and score, start the timer, full draw, first tile, then empty the keyboard buffer (`poke198,0`) so keys pressed while the game loads or draws aren't taken as moves |
| 300–480 | main loop: key wait (with the timer), dispatch, move, wall colors, sound, game over |
| 600 | sound sweep: register `v` from `f` to `e` by `s`, then off and volume back to 15 |
| 610 | 2048 chime (4 rising notes) |
| 620–650 | move sound: the quiet slide, or one coin ding per merge (with the chime after a 2048 or bigger) |
| 660 | no-move woosh (noise, volume fade) |
| 670 | game over tone |
| 900 | draw one tile: cell `x`, power `p`, color `sc` |
| 950 | color one inner wall: `wa`, `ws`, color `wc` |
| 960 | color all four inner walls green |
| 965 | show the key queue with the active key `a$` first, in green |
| 970–985 | show the waiting keys under the board (only the cells in use) |
| 1000–1070 | move all four lines in the direction set by `dc`, `dl`, `ds`, drawing the lines that changed |
| 1100 | turn all 16 tile cells black |
| 5000–5010 | full redraw: title, score, time, border, key help, tiles, queue colors |
| 6000 | poke `w` as two digits at `y`, going left |
| 6100–6120 | timer tick: stop if frozen, compute the seconds, return if unchanged |
| 6130 | draw the time `w` as `mm:ss` |
| 31000 | draw the border |
| 32000 | draw all 16 tiles (full redraw only) |
| 36500 | spawn a tile in a random empty cell and draw it in red |
| 38000 | title bar and `time` label |
| 38100 | key help |
| 39000 | print the score |

## variable table

| variable | meaning |
|---|---|
| `gt%(15)` | the grid: a power per cell, 0 = empty |
| `t%(4)` | line buffer: `t%(0..3)` is one line, wall side first (+65 = just merged); `t%(4)` absorbs the clearing loop's extra pass |
| `sa%(15)`, `cd%(20)` | tables: screen address of each cell, screen code of each power |
| `a$` | key pressed |
| `dc`, `dl`, `ds` | direction: first cell of line 0, step per line, step per cell (see "movement") |
| `db` | direction bit for game over (w 1, a 2, s 4, d 8) |
| `mt` | directions tried without a change since the last move (= the red walls) |
| `wa`, `ws`, `wc` | inner wall of the current direction: color RAM address of its first glyph, step, color |
| `mv` | 1 if the last move changed the board |
| `j`, `lv`, `lm` | one-pass merge: next free position, last tile that can still merge (0 = none), line changed |
| `mz%(7)`, `mn` | the move's merges: new power of each, and how many (0–8); the dings play from them |
| `k`, `n` | ding loop: merge index, first note's pitch |
| `v`, `f`, `e`, `s` | sound sweep (600): register, from, end, step |
| `r` | line number in 1000; also the seed dummy at startup |
| `c` | first cell of the current line; also the screen code of a queued key in 970, and the tens in 6000 |
| `o` | key queue: first cell for the waiting keys (1 while a key is active, else 0) |
| `i` | loop counter |
| `x` | cell index (move routine, drawing, spawning, new game loop); also takes `fre(0)` |
| `p` | a tile's power |
| `sc` | tile color |
| `y` | screen address of a tile; also of the next timer digit in 6000 |
| `co` | 30720, the offset from screen memory to color RAM |
| `q`, `qe`, `ql` | key queue: end of what to show, end of the loop, end of what was shown last |
| `ss` | score |
| `tb`, `te`, `tg` | timer: `ti` at the start of the game, seconds last shown, 1 when stopped (game over or 99:59) |
| `w` | timer: the seconds, then the minutes, being drawn |

## memory

Measured with `?fre(0)` after quitting, on an unexpanded VIC-20 (3583 bytes for program and variables).

| version | PRG bytes | free |
|---|---|---|
| `v0.9` (untightened) | 3156 | 27 |
| first tightening pass | 1200 | 2209 |
| double border | 1239 | 2170 |
| wall colors | 1434 | 1954 |
| key queue (active key in green), GAME OVER on the score row | 1581 | 1800 |
| direction variables renamed (`dc`, `dl`, `ds`, `db`, `mv`) | 1602 | 1779 |
| sound effects | 2010 | 1299 |
| speed pass | 2299 | 887 |
| screen layout (score and time rows, help at the bottom), game timer | 2590 | 582 |

The first tightening pass:

- one move routine instead of four near-copies (1000, 1400, 1800, 2200)
- integer arrays: `gt%()` and `t%()` (2 bytes per element instead of 5); `t%()` shrank from 8 elements to 5
- the border's `data` and `bx$()` array replaced by `{$xx}` string literals
- tile drawing shared by 32000 and 36500 (900), with the power-to-character chain replaced by a formula
- helpers inlined: new tile value, empty-cell search, score add, full-board check (`mt=15` already implies a full board)
- removed: the unused `md`, the unused `a`, the board-size variable `w`, the long names `base`, `idx`, `full`, the redundant `goto` after `then`, `next` variable names, and the spaces in `mt or 1`
- `fre(0)` now runs once per key instead of on every idle pass, into the existing `x`

Plain variables stay floats: an integer scalar takes the same 7 bytes, costs a byte per use for the `%`, and is slower (BASIC V2 converts it to float for every calculation).

## speed

Measured in xvic with `ti` (jiffies, 1/60 s), on a board where every line slides right (see "testing" for the line that measures it). A successful move went from **194 jiffies (3.2 s) to 103 (1.7 s)**; boards where fewer lines move are faster still.

Before, per piece (in jiffies): move calculation 56, redraw of all 16 tiles 59, key queue 17 per call × 3, all four walls 10, then spawn 7, slide sound 5, one wall 2, score 1. What changed:

| change | effect |
|---|---|
| draw during the move, only lines that changed (1055–1065), instead of redrawing all 16 tiles after it | removes the 59-jiffy redraw; a line that didn't change costs nothing |
| `sa%()`/`cd%()` tables instead of computing each tile's address and character | cheaper per tile |
| 1100 turns all tile colors black at the start of a move | replaces the old redraw's job of clearing blue/red highlights (5 jiffies) |
| key queue redraws only the cells in use, colors set once by 5000 | 17 → 4 jiffies per call |
| one wall back to green; all four only when some are red | 10 → 2 jiffies usually |
| one-pass merge and slide instead of two loops | move calculation 47 → 37 on a board where nothing moves |
| hot variables created first (line 100), `co` for 30720 | 37 → 35 (static board), 71 → 64 (every line moves) |
| skip unchanged cells within a changed line | helps lines with gaps; no change on the test board |

Memory: the speed pass cost 412 bytes (tables, extra lines, earlier variables).

**BASIC V2 speed notes** (all used here): variables are found by searching them in creation order, so create the hottest ones first; number literals are converted from text every time they run, so a variable is faster for a long constant; an array lookup beats recomputing a formula; and doing less (fewer cells, fewer loops) beats everything.
