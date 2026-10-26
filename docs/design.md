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

Each cell stores the tile's **power of 2**: 1 means 2, 2 means 4, 11 means 2048, and 0 means empty. When a tile is drawn, line 910 turns its power `p` into a screen code:

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

A merged tile carries `+65` in the grid until it is drawn (see below); powers never exceed 20, so anything over 64 is a flagged tile.

## movement

All four directions use one routine, 1000. The grid is treated as four **lines** (rows for left/right, columns for up/down), and each line is read starting from the side the tiles move toward. Three variables, set by the key dispatch (400–440), describe the direction:

- `b`: the cell where line 0 starts (its cell nearest the wall)
- `l`: how far the start moves from one line to the next
- `s`: how far a cell is from the previous one along a line, walking away from the wall

| key | direction | `b` | `l` | `s` | `m` |
|---|---|---|---|---|---|
| `w` | up | 0 | 1 | 4 | 1 |
| `a` | left | 0 | 4 | 1 | 2 |
| `s` | down | 12 | 1 | -4 | 4 |
| `d` | right | 3 | 4 | -1 | 8 |

Cell `i` of line `r` is `gt%(b+r*l+i*s)`, so position 0 of the line buffer is always the cell against the wall. For each line, 1000:

1. copies the line into `t%(0..3)` (line 1000; `c` is the line's first cell)
2. merges pairs, scanning from the wall (1010–1030)
3. slides the tiles toward the wall (1040)
4. writes the line back (1050)

and sets `dm=1` if anything merged or moved. `m` is the direction's bit for game over detection.

### merge rules

The scan remembers the last tile it saw in `mp`. Two tiles merge if:

```
t%(i) = t%(mp)
```

Then the tile nearer the wall takes the merge flag and the other is cleared:

```
ss = ss + 2^(t%(i)+1)
t%(mp) = t%(i) + 65
t%(i) = 0
mp = 4
dm = 1
```

`mp=4` means "no tile yet". `t%(4)` is a sentinel: it's always 0 and is never compared equal to a real tile, so a single test (`ift%(i)<>t%(mp)thenmp=i`) covers both "first tile" and "different tile". Resetting `mp` after a merge means a merged tile can't merge again in the same move, matching 2048's behavior.

### sliding

One pass: `j` is the next free position from the wall; each tile is moved from `i` to `j`, and `j` advances. A tile moved (`j<i` before advancing, tested as `j<=i` after) sets `dm=1`.

## merge flag and visual feedback

A merged tile gets **65** added. When the tiles are next drawn (32000), the renderer sees the flag, strips 64 and writes the result back:

```
if p > 64 then sc = 6 : p = p - 64 : gt%(x) = p
```

So:

- `+65` then `-64` leaves the tile at its old power **+1**: this is the step up to the next power, the actual merge
- the tile is drawn in **blue** (color 6) for that one redraw, so the player sees which tiles merged
- every other tile is drawn in black (color 0)

Because the flag is stripped on the very next draw, the grid holds only true powers between moves.

## random tile placement

At the start of a game and after any successful move, 36500:

1. picks a random cell `x` until it finds an empty one
2. picks the power: 1 (a "2") 90% of the time, else 2 (a "4"): `p=1-(rnd(1)>=.9)`
3. stores it and draws it in **red** (color 2), so the player sees where it appeared

36500 is only called when at least one cell is empty (after a successful move, or on an empty board), so the search always ends.

The seed is `rnd(-ti)` at startup, so every run deals differently.

## scoring

`ss` is the score. Each merge adds the merged tile's value, `2^(p+1)` for two tiles of power `p` (two 4s make an 8 and score 8), as in 2048. 39000 prints it on the `score:` row after every successful move and on every full redraw. A new game resets `ss` to 0.

## game over detection

The game doesn't search for possible merges. Instead, `mt` records which directions the player has tried without anything moving, one bit each (`m`: w 1, a 2, s 4, d 8). A move that changes the board resets `mt` to 0; a move that doesn't adds its bit (470, `mt=mormt`). A new game or a redraw also resets `mt`.

When `mt=15`, all four directions have failed. That can only happen on a full board with no merges left (with an empty cell, some tile can always slide into it), so 470 prints "game over" at the right end of the score row (reverse red, columns 13–21; `tab` can't be used there, see the cheatsheet). It gets there with `{home}`, 4 `{down}`s and 9 `{left}`s: `{left}` at column 0 wraps to the end of the row above, so this is 3 bytes shorter than 13 `{right}`s and resets `mt`. The score fits to its left up to 6 digits. The program keeps running: `n` starts a new game, `q` quits.

## move indicator (wall colors)

The four inner-wall glyphs on the side the tiles move toward show what a move did:

| when | color |
|---|---|
| while the move runs | blue (6) |
| the move changed the board | green (5), the border color |
| nothing moved | red (2), until a move changes the board |

The red sides are exactly the bits in `mt`, so at game over all four inner walls are red, showing that every direction was tried. There's no "invalid move" text; the red wall says it.

The colors are poked into color RAM; the glyphs don't change. 400–440 set the wall for the direction along with `b`, `l`, `s`, `m`:

| key | wall | `wa` (color RAM of the first glyph) | `ws` (step) |
|---|---|---|---|
| `w` | top, row 10, columns 9–12 | 38629 | 1 |
| `a` | left, column 8, rows 11–14 | 38650 | 22 |
| `s` | bottom, row 15, columns 9–12 | 38739 | 1 |
| `d` | right, column 13, rows 11–14 | 38655 | 22 |

450 colors the wall blue (950 with `wc=6`) and runs the move. A move that changed the board goes to 460, which recolors all four inner walls green (960; this also clears any red sides). Otherwise 465 colors the wall red (950 with `wc=2`).

A redraw (`r`) or a new game reprints the whole border in green and resets `mt`, so the screen and the game over check agree: the player tries the dead-end directions again to rediscover them. The score is unaffected.

## screen rendering

| routine | draws |
|---|---|
| 5000 | full redraw: title (38000), border (31000), tiles (32000), then the score (39000) |
| 32000 | all 16 tiles |
| 900 | one tile: cell `x`, power `p`, color `sc` |
| 39000 | the score |

### border drawing

31000 prints a double box in green, 8×8 characters at `tab(7)` (columns 7–14, centered on the 22-column screen), rows 9–16. It uses the square box glyphs and the horizontal line as `{$xx}` codes in string literals:

```
row  9   b0 60 b2 b2 b2 b2 60 ae     outer top
row 10   7d b0 b1 b1 b1 b1 ae 7d     inner top
rows 11-14  ab b3 .. .. .. .. ab b3  sides; the 4x4 tiles go in the gap
row 15   7d ad b2 b2 b2 b2 bd 7d     inner bottom
row 16   ad 60 b1 b1 b1 b1 60 bd     outer bottom
```

┌ `b0`, ┐ `ae`, └ `ad`, ┘ `bd`, ─ `60`, │ `7d`, tees `b1`/`b2`/`b3`/`ab`. The tees of the outer and inner boxes face each other, so each grid row and column gets a rung between the two walls. The first `print` has no `{down}`: it starts on the row right after the key help, which puts the tiles on rows 11–14. The "inner wall" is the four tee glyphs beside each side of the grid (row 10, row 15, column 8 and column 13 next to the tiles).

### tile drawing

900 pokes a tile straight into screen memory, inside the border:

```
sp = 7931 + x + 18*int(x/4)
```

That's screen memory (7680) + row 11 × 22 + column 9, plus 22 per grid row and 1 per column: `x + 18*int(x/4)` is `row*22 + col` for `x = row*4 + col`. The color goes to `sp + 30720` in color RAM.

Tile colors: black for a settled tile, blue for a tile that just merged, red for the tile that just appeared.

## key queue

A move takes about 2 seconds, and keys pressed meanwhile wait in the KERNAL keyboard buffer (see the cheatsheet: count at 198, keys at 631–640). Row 18 under the board, columns 7–16 (screen 8083, color RAM 38803), shows them: the key being worked on in **green** in the first cell, then the waiting keys in blue, oldest first, and spaces for the rest of the 10 cells.

```
965 poke8083,asc(a$)and63:poke38803,5:o=1
970 fori=oto9:c=32:ifi-o<peek(198)thenc=peek(631+i-o)and63
980 poke8083+i,c:poke38803+i,6:next:o=0:return
```

965 puts the active key (`a$`, already taken by `get`) in the first cell and falls into 970 with the offset `o=1`, so the waiting keys start in the second cell. Called as `gosub970` (with `o=0`, which 980 restores), the waiting keys start in the first cell. `and63` turns a PETSCII letter (65–90) into its screen code (1–26); digits and space are the same in both. 970 only peeks, so the keys stay queued for `get`.

| when | call | shows |
|---|---|---|
| a move starts (450) | 965 | the active key, then the waiting keys |
| the move's result is known (460, before the slow redraw) | 965 | the same, plus keys typed during the move |
| the move is complete (end of 460, or 465 for a move that changed nothing) | 970 | only the waiting keys: the active key leaves the queue |

So the leftmost green key is always the move in progress, and it only disappears once that move is completely done.

## control loop

```
300–480
```

300 waits for a key. 310 forces a garbage collection (`x=fre(0)`, see "memory") and then dispatches:

- redraw: r  
- debug dump: % (prints each cell's index and power)  
- new game: n  
- quit: q  
- movement keys: w, a, s, d (400–440 set the direction and its wall, 450 colors the wall blue, shows the key queue (965) and runs the move)  

After a move that changed the board (`dm=1`, line 460):

- the inner walls turn green (960)
- the key queue is shown again (965), with any keys pressed during the move
- the tiles are redrawn (32000)
- a new tile is spawned (36500)
- the score is shown (39000)
- the active key leaves the queue (970)

Otherwise 465 colors the wall red, takes the active key off the queue (970) and records the failed direction, and 470 checks for game over.

## title screen

The title screen is drawn by:

```
gosub 38000
```

It clears the screen and uses reverse-video PETSCII and color codes to display:

- game title  
- author  
- control instructions  

## routine map

| line | routine |
|---|---|
| 100 | init: dims, seed |
| 200 | new game: clear the grid and score, full draw, first tile |
| 300–480 | main loop: key wait, dispatch, move, wall colors, game over |
| 900 | draw one tile: cell `x`, power `p`, color `sc` |
| 950 | color one inner wall: `wa`, `ws`, color `wc` |
| 960 | color all four inner walls green |
| 965 | show the key queue with the active key `a$` first, in green (falls into 970) |
| 970 | show the waiting keys under the board (970–980) |
| 1000 | move all four lines in the direction set by `b`, `l`, `s` |
| 5000 | full redraw: title, border, tiles, score |
| 31000 | draw the border |
| 32000 | draw all tiles (strips the merge flag) |
| 36500 | spawn a tile in a random empty cell and draw it in red |
| 38000 | title screen and key help |
| 39000 | print the score |

## variable table

| variable | meaning |
|---|---|
| `gt%(15)` | the grid: a power per cell, 0 = empty (+65 = just merged, until drawn) |
| `t%(4)` | line buffer: `t%(0..3)` is one line, wall side first; `t%(4)` is the always-0 sentinel for `mp` |
| `a$` | key pressed |
| `b`, `l`, `s` | direction: first cell of line 0, step per line, step per cell (see "movement") |
| `m` | direction bit for game over (w 1, a 2, s 4, d 8) |
| `mt` | directions tried without a change since the last move (= the red walls) |
| `wa`, `ws`, `wc` | inner wall of the current direction: color RAM address of its first glyph, step, color |
| `dm` | 1 if the last move changed the board |
| `mp` | merge scan: position of the last tile seen, 4 = none |
| `r` | line number in 1000; also the seed dummy at startup |
| `c` | first cell of the current line; also the screen code of a queued key in 970 |
| `o` | key queue: first cell for the waiting keys (1 while a key is active, else 0) |
| `i`, `j` | loop counters; `j` is also the next free position when sliding |
| `x` | cell index (drawing, spawning, new game loop); also takes `fre(0)` |
| `p` | a tile's power |
| `sc` | tile color |
| `sp` | screen address of a tile |
| `ss` | score |

## memory

Measured with `?fre(0)` after quitting, on an unexpanded VIC-20 (3583 bytes for program and variables).

| version | PRG bytes | free |
|---|---|---|
| `v0.9` (untightened) | 3156 | 27 |
| first tightening pass | 1200 | 2209 |
| double border | 1239 | 2170 |
| wall colors | 1434 | 1954 |
| key queue (active key in green), GAME OVER on the score row | 1581 | 1800 |

The first tightening pass:

- one move routine instead of four near-copies (1000, 1400, 1800, 2200)
- integer arrays: `gt%()` and `t%()` (2 bytes per element instead of 5); `t%()` shrank from 8 elements to 5
- the border's `data` and `bx$()` array replaced by `{$xx}` string literals
- tile drawing shared by 32000 and 36500 (900), with the power-to-character chain replaced by a formula
- helpers inlined: new tile value, empty-cell search, score add, full-board check (`mt=15` already implies a full board)
- removed: the unused `md`, the unused `a`, the board-size variable `w`, the long names `base`, `idx`, `full`, the redundant `goto` after `then`, `next` variable names, and the spaces in `mt or 1`
- `fre(0)` now runs once per key instead of on every idle pass, into the existing `x`

Plain variables stay floats: an integer scalar takes the same 7 bytes, costs a byte per use for the `%`, and is slower (BASIC V2 converts it to float for every calculation).
