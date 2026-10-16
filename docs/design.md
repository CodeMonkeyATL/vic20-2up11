# 2up11 design notes

2up11 is a VIC-20 BASIC V2 puzzle game inspired by 2048, adapted for a 4x4 grid and the constraints of an unexpanded VIC-20. Tiles represent **powers of 2**, not numeric values. The display uses PETSCII screen codes that progress through the VIC-20 character set in a predictable sequence.

This document describes the internal mechanics of the game, including tile encoding, movement, merging, random tile placement, and screen rendering.

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

`w=3` indicates the last column index (0–3).

## tile encoding

Tiles represent powers of 2. Instead of storing numeric values, the game stores **PETSCII screen codes** that correspond to characters in the VIC-20 character set.

The progression is:

```
1,2,3,4,5,6,7,8,9,0, inverted 1–9, inverted 0
```

This gives each power of 2 a distinct visual identity.

## merge flag (dm)

Movement routines set:

```
dm = 1
```

whenever a tile moves or merges. This signals the main loop to spawn a new tile.

## merge encoding and visual feedback

When two tiles merge, the game temporarily adds **65** to the tile’s code:

```
t(c) = t(c) + 65
```

This does **not** change the logical tile value.  
The +65 is a **one-frame visual flag** that tells the renderer:

- “this tile just merged”
- color it **green** for one redraw cycle

During rendering, the display routine immediately strips the flag:

```
if p > 64 then sc = 6 : p = p - 64
```

So:

- the **grid stores the true tile value**
- the **+65 flag is temporary**
- the player gets a clear visual cue of merges

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

Two tiles merge if:

```
t(c) = t(mp)
```

After merging:

```
t(c) = t(c) + 65
t(mp) = 0
dm = 1
```

Only one merge per tile per move is allowed, matching 2048’s behavior.

### compression rules

Tiles slide toward the movement direction until blocked by:

- another tile  
- the edge of the grid  

Compression loops repeat until no movement occurs.

## random tile placement

Random tile placement occurs after any successful move (`dm=1`):

```
gosub 36500
```

The process:

1. Choose a random empty cell (`gosub 36000`)
2. Generate a new tile value (`gosub 33000`)
   - 90% chance → **1**
   - 10% chance → **2**
3. Store the logical tile value in the grid
4. Renderer converts the logical value into the correct PETSCII display character

Tile codes like 129 or 130 are **not part of the game logic**.  
They are internal PETSCII artifacts and not relevant to the design.

## screen rendering

Screen rendering is handled by:

```
gosub 31000 – draw border
gosub 32000 – draw tiles
```

### border drawing

The border uses PETSCII box-drawing characters loaded from:

```
gosub 30000
```

### tile drawing

Tiles are drawn at:

```
sp = 7901 + t + r*22 + c
```

Color RAM is updated at:

```
cp = sp + 30720
```

Tile color is determined by:

```
if p > 64 then sc = 6 : p = p - 64
```

This gives newly merged tiles a distinct color.

## control loop

The main loop:

```
300–440
```

Handles:

- movement keys: w, a, s, d  
- new game: n  
- redraw: r  
- debug dump: %  
- quit: q  

After each move:

- if `dm=1`, a new tile is spawned  
- the board is redrawn  

## game over detection

Game over occurs when:

```
gt(i) <> 0 for all i
```

If the board is full and there are no more possible merges:

```
print "game over"
```

Execution ends.

## title screen

The title screen is drawn by:

```
gosub 38000
```

It uses reverse-video PETSCII and color codes to display:

- game title  
- author  
- control instructions  

---

This document reflects the current behavior of 2up11 based on the latest BASIC source. Future revisions can expand this with memory maps, PETSCII tables, and optimization notes.
