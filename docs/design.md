# 2up11 design notes

2up11 is a VIC-20 BASIC V2 puzzle game inspired by 2048, adapted for a 4x4 grid and the constraints of an unexpanded VIC-20. Tiles represent **powers of 2**, not numeric values. The display uses PETSCII screen codes that progress through the VIC-20 character set in a predictable sequence.

This document describes the internal mechanics of the game, including tile encoding, movement, merging, random tile placement, scoring, game over detection and screen rendering. The routine map and variable table are at the end.

## grid model

The game uses a fixed 4x4 grid, represented as a 1-dimensional array:

```
gt(0) to gt(15)
```

The grid is stored row-major:

```
row 0: gt(0)  gt(1)  gt(2)  gt(3)
row 1: gt(4)  gt(5)  gt(6)  gt(7)
row 2: gt(8)  gt(9)  gt(10) gt(11)
row 3: gt(12) gt(13) gt(14) gt(15)
```

`w=3` is the last row and column index (0–3).

## tile encoding

Each cell stores the tile's **power of 2**: 1 means 2, 2 means 4, 11 means 2048, and 0 means empty. Routine 900 turns a power `p` into the screen code `dp` that is poked into screen memory:

| power `p` | shown as | screen code `dp` |
|---|---|---|
| 0 | blank | 32 |
| 1–9 | `1`–`9` | `p+48` |
| 10 | `0` | 48 |
| 11–19 | reversed `1`–`9` | `p+166` |
| 20 | reversed `0` | 176 |

So the display is the last digit of the power, and reverse video marks powers 11 and up. Two values outside the 0–20 range appear in the grid only for a moment (see below): a merged tile carries `+65` until it is drawn, and a new tile carries `+128` until it is placed.

## merge flag (dm)

Movement routines set:

```
dm = 1
```

whenever a tile moves or merges. This tells the main loop to redraw the tiles and spawn a new tile.

## merge encoding and visual feedback

When two tiles merge, the merged tile's value gets **65** added:

```
t(c) = t(c) + 65
```

The +65 does two jobs at once. When the tiles are next drawn (32000), the renderer sees the flag, strips 64 and writes the result back:

```
if p > 64 then sc = 6 : p = p - 64
gt(x) = p
```

So:

- `+65` then `-64` leaves the tile at its old power **+1**: this is the step up to the next power, the actual merge
- the tile is drawn in **blue** (color 6) for that one redraw, so the player sees which tiles merged
- every other tile is drawn in black (color 0)

Because the flag is stripped on the very next draw, the grid holds only true powers between moves. The merge flag only works because powers never exceed 20: anything over 64 is a flagged tile.

## movement and merging

Movement is handled by four routines:

```
gosub 1000 – move right
gosub 1400 – move left
gosub 1800 – move up
gosub 2200 – move down
```

Each movement routine follows the same pattern:

1. Extract a row or column into `t()`
2. Scan for merges
3. Perform merges (adding 65)
4. Compress tiles toward the movement direction
5. Write the updated row/column back into `gt()`
6. Set `dm=1` if any merge or movement occurred

### merge rules

The merge scan starts at the side the tiles move toward and remembers the last tile it saw in `mp` (`-1` = none). Two tiles merge if:

```
t(c) = t(mp)
```

After merging, one of the pair takes the flag and the other is cleared:

```
t(c) = t(c) + 65
t(mp) = 0
mp = -1
dm = 1
```

Right and down flag `t(c)` and clear `t(mp)`, as above; left and up flag `t(mp)` and clear `t(c)`. Either way, compression then slides the merged tile to the side the tiles move toward.

Resetting `mp` means a merged tile can't merge again in the same move, matching 2048's behavior. Each merge also adds to the score (39100, see "scoring").

### compression rules

Tiles slide toward the movement direction until blocked by:

- another tile  
- the edge of the grid  

Each pass moves tiles one cell; `mm` records whether the pass moved anything, and passes repeat until one doesn't.

## random tile placement

Random tile placement occurs at the start of a game and after any successful move (`dm=1`):

```
gosub 36500
```

The process:

1. Choose a random empty cell `x` (36000, which retries until it finds an empty one)
2. Generate a new tile value (33000)
   - 90% chance → **129** (power 1, a "2")
   - 10% chance → **130** (power 2, a "4")
3. Store it in the grid; 36510 subtracts 128 straight away, leaving the true power
4. Draw the tile in **red** (color 2), so the player sees where it appeared

The +128 marks the cell as taken while the value is being placed; it never survives past 36510.

The seed is `rnd(-ti)` at startup, so every run deals differently.

## scoring

`ss` is the score. Each merge calls 39100 with `sv`, the power of the two tiles before they merged:

```
ss = ss + 2^(sv+1)
```

That adds the merged tile's value (two 4s make an 8 and score 8), as in 2048. 39000 prints the score on the title area's `score:` row after every successful move. A new game resets `ss` to 0.

## game over detection

The game doesn't search for possible merges. Instead, `mt` records which directions the player has tried without anything moving, one bit each:

| key | bit |
|---|---|
| `w` | 1 |
| `a` | 2 |
| `s` | 4 |
| `d` | 8 |

A move that changes the board resets `mt` to 0. While `mt` is non-zero, the main loop calls 6000 on each pass, which checks whether the board is full (37000 sets `full`). If it is, and `mt=15` (all four directions failed), it prints "game over" and resets `mt`.

So a full board with no merges left is reported after the player has tried all four directions. The program keeps running: `n` starts a new game, `q` quits.

## screen rendering

Screen rendering is handled by:

```
gosub 5000 – full redraw: title (38000), border (31000), tiles (32000)
gosub 32000 – draw tiles
gosub 39000 – show the score
```

### border drawing

The border uses PETSCII box-drawing characters loaded into `bx$()` by:

```
gosub 30000
```

31000 prints the box in green, centered with `tab(t)` where `t=(22-w-4)/2` (7.5, so `tab` uses 7).

### tile drawing

Tiles are poked straight into screen memory, inside the border:

```
sp = 7923 + t + r*22 + c
```

7923 is row 11, column 1 of screen memory (7680); with `t` (7.5, truncated by `poke`) the grid sits at rows 11–14, columns 8–11.

Color RAM is updated at:

```
cp = sp + 30720
```

Tile colors: black for a settled tile, blue for a tile that just merged (32055), red for the tile that just appeared (36550).

## control loop

The main loop:

```
300–500
```

Handles:

- movement keys: w, a, s, d  
- new game: n  
- redraw: r  
- debug dump: % (prints each cell's index and power)  
- quit: q  

After a move that changed the board (`dm=1`, line 480):

- the tiles are redrawn (32000)
- a new tile is spawned (36500)
- the score is shown (39000)

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
| 100 | init: `w`, dims, seed, box characters (30000) |
| 200 | new game: clear the grid and score, full draw, score, first tile |
| 300–500 | main loop: game over check, key dispatch |
| 900 | power `p` → screen code `dp` |
| 1000 | move right |
| 1400 | move left |
| 1800 | move up |
| 2200 | move down |
| 5000 | full redraw: title, border, tiles |
| 6000 | game over check |
| 30000 | read the box characters into `bx$()` |
| 31000 | draw the border |
| 32000 | draw all tiles (strips the merge flag) |
| 33000 | new tile value `nt` (129 or 130) |
| 36000 | pick a random empty cell `x` and store a new tile |
| 36500 | spawn a tile and draw it in red |
| 37000 | full check: `full=1` if no cell is empty |
| 38000 | title screen and key help |
| 39000 | print the score |
| 39100 | add a merge to the score |

## variable table

BASIC only reads the first two letters of a name, so `base`, `idx` and `full` are really `ba`, `id` and `fu`.

| variable | meaning |
|---|---|
| `gt(15)` | the grid: a power per cell, 0 = empty |
| `t(7)` | line buffer for one row or column (only 0–3 used; sized for a planned board up to 8x8) |
| `t` | border tab offset (7.5); separate from the array `t()` |
| `w` | last row/column index (3) |
| `a$` | key pressed |
| `a` | result of `fre(0)`, which forces garbage collection on each loop pass; the value isn't used |
| `dm` | 1 if the last move changed the board |
| `mt` | directions tried without a change since the last move (w 1, a 2, s 4, d 8) |
| `md` | direction of the last key (0 w, 1 a, 2 s, 3 d); set but never read |
| `mp` | merge scan: index of the last tile seen, -1 = none |
| `mm` | compression: 1 if the last pass moved a tile |
| `d` | compression: the cell a tile slides into |
| `base` | index in `gt()` of the current row's first cell |
| `idx` | index in `gt()` of the current cell in a column |
| `r`, `c` | row and column; `r` is also the seed dummy at startup and `j*22` in 32000 |
| `i`, `j`, `x`, `zt` | loop counters; `x` is also the cell picked by 36000 |
| `p` | a tile's power while drawing or generating |
| `dp` | screen code for `p` (from 900) |
| `sc` | tile color |
| `sp`, `cp` | screen and color RAM address of a tile |
| `nt` | new tile value (129 or 130) |
| `full` | 1 if the grid has no empty cell |
| `ss` | score |
| `sv` | power of the tiles that just merged, for the score |
| `bx$(15)` | box-drawing characters for the border |
