# BASIC coding guidelines

How we write Commodore BASIC V2 for the unexpanded VIC-20. Memory is the scarcest resource: there are 3583 bytes free for program **and** variables combined. Write code that is efficient in tokens and data, but that a person can still read. Choose the cheaper construct when it's about as clear; don't go for cleverness that saves a byte and costs an hour of puzzling.

## What things cost

Measured with petcat, or standard BASIC V2 storage:

| Item | Cost |
|---|---|
| A new line | 5 bytes overhead (link 2, line number 2, terminator 1) |
| `:` between statements | 1 byte. So joining statements onto one line saves 4 bytes per line removed. |
| Keyword (`print`, `gosub`, …) | 1 byte, however long it lists |
| Space outside a string | 1 byte |
| Blank line in the source | 0 bytes: petcat skips it (verified: identical PRG) |
| Each digit of a number literal | 1 byte (`7680` = 4 bytes every time it appears) |
| Simple variable (any type) | 7 bytes, once |
| Array | 5 + 2×dims bytes header, plus per element: float 5, integer `%` 2, string 3 + text |
| `rem` | 1 byte + its text, plus 5 if it's on its own line |

Check real usage with `?fre(0)` after a run. Re-check whenever data structures change.

`buildtools/check-basic.ps1` checks the mechanical rules below on every Build: jump targets, the 88-character limit, spaces outside strings, and line numbering. The rest (naming, data structures, constructs) still needs a reviewer's eye.

## Rules

### Source formatting
- **No spaces in code.** Spaces belong only inside strings, where they're content. The space after the line number in the source is free, because petcat drops it.
- **Separate routines with a blank line.** Blank lines cost nothing, so keep them even in a tightened program; they make the `.bas` file easier to read.
- **Joining statements with `:` is postponed while developing.** Keep one statement or small group per line while the code is being written and debugged; separate lines are easier to edit, test and `goto`. Joining is a separate pass, done only when asked to "tighten" the program's memory (or similar), usually when we're near the memory ceiling. If memory isn't tight, it may never happen. During a tightening pass, merge lines until something needs a line number (a `goto`/`gosub` target, or the line after an `if` whose rest must be skipped) or the 88-character limit is reached. That saves 4 bytes per line removed.
- **Line length limit: 88 characters as the VIC lists it** (4 screen rows). Count the line number, the space after it, keywords at full length, and each petcat code such as `{blk}` as **1** character. A longer line runs, but can't be edited on the VIC, so it's not allowed.

### Petcat codes over `chr$()`
- Put control and color characters in strings as petcat codes: `{blk}`, `{clr}`, `{reverse on}`, `{down}` cost 1 byte each (petcat rejects the short form `{rvs on}`). `chr$(144)` costs 6 bytes, plus concatenation.
- For graphic characters, use petcat's named codes where they exist (`{CBM-+}`), or `{$xx}` with two lowercase hex digits for any other code (`{$e6}` = 230). Both cost 1 byte inside a string; see the cheatsheet. Use `chr$()` only for 34 (quote) and 0, which can't go inside a string literal, and then assign it to a variable once instead of repeating it.

### Variables
- **Names are one or two characters.** Only two are significant anyway, so longer names waste bytes and invite collisions (`pp` and `ppx` are the same variable).
- **Name related variables as a family** with a shared first letter: e.g. `bt`, `bs`, `be`, `bi` for banner type, start, end and info. The first letter says which thing; the second says which property.
- **Avoid names that contain a keyword**, because they tokenize wrong: `to`, `if`, `or`, `on`, `fn`, `go`, and also `st`, `ti` (reserved system variables).
- **Keep a variable table** (name → meaning) in `docs/design.md`. Two-letter names stay readable when the table exists, and it prevents accidental reuse.
- Reuse short-lived temporaries (`i`, `j`, `t`) across routines instead of inventing new names. Every distinct variable costs 7 bytes forever.
- Store a number literal used many times in a variable (e.g. `sb=7680`); a 2-byte reference beats a 4-digit literal each time.

### Data structures
- **Integer arrays (`%`) for small whole numbers** (colors, flags, indexes, screen addresses up to 32767): 2 bytes per element instead of 5. Simple integer variables save nothing and are slower, so use `%` only on arrays.
- **Always `dim`**, sized to need. An undimensioned array silently allocates 11 elements per dimension.
- **Use element 0.** Arrays start at 0; leaving it empty wastes an element per row.
- Pack small values when it stays clear (e.g. one array holding a value per slot, rather than parallel arrays).
- Prefer computing a value over storing a table, when the formula is short. `data` costs twice: once in the program text, and again in the array it's read into.
- Free init-only structures by reusing their names for something else later, or keep them small. Arrays can't be un-`dim`med.
- Avoid building strings in loops. Every concatenation leaves garbage, and garbage collection pauses the program. A string assigned straight from a literal costs no extra heap.
- If a program does create string garbage, call `t=fre(0)` (using an existing temp variable) at a quiet moment, such as after setup or between rounds. This forces garbage collection at that point. It doesn't reclaim more than the automatic collection would, which runs when string space fills up. But it moves that pause, which can last seconds on BASIC V2, away from gameplay. Code that only handles numbers and arrays never needs it.

### Code constructs
- `next` without a variable name (smaller and faster), unless a nested `next i,j` is clearer.
- `if x then 300`, not `if x then goto 300`.
- `if x then` when testing for non-zero, rather than `if x<>0 then`.
- `on n gosub a,b,c` for dispatch instead of chains of `if`.
- **`if` rules, verified in xvic:**
  - **A false `if` skips the rest of the line**, including every statement after a `:`. `if1thenprint"a";:if0thenprint"b";:print"c"` prints only `a`. Anything that must always run goes on the next line.
  - **Nested `if` is legal**: `ifathenifbthen...` runs only when both are true. It's the same rule applied twice.
  - **Nested `if` short-circuits; `and` doesn't.** `ifi<4thenifz(i)=0then...` is safe, but `ifi<4andz(i)=0then...` evaluates `z(i)` anyway and stops with `?BAD SUBSCRIPT` when `i` is out of range. Use the nested form when the second test is only valid if the first passed.
  - **`and`/`or` are bitwise on 16-bit integers.** A comparison yields -1 (true) or 0 (false), so `ifa=1andb=2` is fine. But `ifaandb` with `a=1`, `b=2` is **false** (1 AND 2 = 0). Combine comparisons with `and`/`or`; don't combine raw values. Use a nested `if` or explicit comparisons instead.
  - **There's no `else`.** Write it as `ifcthen<then-part>:goto<after>` on one line, with the else part on the next line(s).
  - **For readability:** at most two levels of nesting on a line. For anything more complex, split it across lines with `goto`s, or move the logic into a subroutine.
- Subroutines over repeated code once a sequence appears twice or more and is longer than the `gosub` plus its setup.
- Define frequently used variables first (in the init line). BASIC searches variables in creation order, so early ones are faster.

### Advanced code constructs

These rely on the fact that a comparison is a number: **true is -1, false is 0**, and `if` treats any non-zero value as true. `and`, `or` and `not` work bit by bit on 16-bit integers; because -1 has all bits set, they behave as logic when their inputs are comparisons. All behavior below was verified in xvic.

**Combining conditions.** Use `and`/`or` between *comparisons* to fold decisions onto one line:
```
ifx>0andx<23then...          range check
ifk=1ork=5then...            several accepted keys
```
Priority order: comparisons, then `not`, then `and`, then `or`. So `ifk=1ork=5andx>0` means `k=1 or (k=5 and x>0)`. When mixing `and` with `or`, add parentheses for clarity even when the default grouping happens to be right; they cost one byte each.

**Comparisons as numbers.** A comparison can replace an `if` entirely:
```
x=x-(k=29)+(k=157)           cursor right: x+1, cursor left: x-1, other keys: no change
n=n-(a>b)                    count: adds 1 when a>b
```
Use this for simple increment/decrement updates, keyboard movement in particular. Limit it to two such terms per expression; beyond that, readability falls apart.

**Bit masks.** Pack several small values into one number when it saves real memory:
```
c=pand7                      read the low 3 bits (e.g. a color 0-7)
p=por8                       set bit 3
p=pand247                    clear bit 3 (255-8)
```
Document the bit layout of any packed value in `docs/design.md`.

**Traps:**
- **`not` works bit by bit:** `not1` is -2, which is still true. `ifnotfthen` works only when `f` is exactly 0 or -1, as it is after `f=(a=b)`. For flags set to 1, write `iff=0then`.
- **`and`/`or`/`not` accept only -32768 to 32767.** `38400and7` stops with `?ILLEGAL QUANTITY`. Color RAM starts at 38400, so mask the value read by `peek`, never the address.
- **Raw values don't combine like conditions:** `ifaandb` with `a=1`, `b=2` is false (1 AND 2 = 0). Compare first: `ifa<>0andb<>0`.
- **No short-circuit:** both sides of `and`/`or` are always evaluated. When the second test is only valid if the first passed, use a nested `if` (see the `if` rules above).

### Structure and comments
- Each routine gets its own line-number block (e.g. 1000, 2000, 2100) so code can grow inside a block without renumbering.
- **Comments are free to use while developing, and are stripped when tightening.** `rem` costs memory, and petcat turns unnumbered source lines into real numbered lines. That's an acceptable cost during development, so explain code with `rem`s as needed. In a tightening pass (see "Source formatting"), remove them. Move anything worth keeping into `docs/design.md`, and make sure no `goto`/`gosub` targets a removed line. The variable table and routine map live in `docs/design.md` from the start.

## When rules conflict

Memory wins over speed, except in code that runs every frame or keypress. Readability wins over saving one or two bytes. If a trick saves real memory but needs explaining, use it and explain it: a `rem` is fine while developing, but the lasting explanation belongs in `docs/design.md`.
