# vic20-2up11

2up11 is a VIC-20 BASIC V2 puzzle game written for an unexpanded VIC-20. It is inspired by the mechanics of 2048, but adapted for the constraints of the VIC-20 and a 4x4 grid. Tiles represent **powers of 2** rather than numeric values, so the board displays PETSCII symbols instead of numbers. Matching tiles combine, new tiles spawn, and the goal is to reach the highest power of 2 you can before the board fills.

This repository contains the current version of the BASIC source and an automated build workflow that generates a `.prg` file whenever a `.bas` file is merged through a pull request.

## features

- written entirely in BASIC V2  
- runs on an unexpanded VIC-20  
- 4x4 grid adapted from 2048-style gameplay  
- Tiles represent powers of 2 and are displayed using PETSCII characters. The visual progression follows the VIC‑20 screen code sequence (1‑9, 0, inverted 1‑9, 0), giving each power a distinct appearance.  
- supports directional movement, tile merging, and score tracking  
- deterministic and repeatable logic for testing  
- builds automatically through GitHub Actions using a repo-stored petcat executable  

## repository layout

```
src/
  2up11.bas        main BASIC source file

prgs/
  (auto-generated .prg files created by the GitHub Action)

tools/
  petcat           linux petcat executable used by CI
  petcat.exe       windows petcat executable for local development

docs/
  design.md        optional notes about game logic or memory usage
  changelog.md     version history

.github/
  workflows/
    build-prg.yml  automatic build on PR merge
```

## building

The `.prg` file is generated using `petcat`. The repository includes both Linux and Windows versions of petcat in the `tools` folder.

To build manually:

```
petcat -w2 -o 2up11[.prg] src/2up11.bas
```

This produces a PRG that can be loaded on a VIC-20 or in VICE.

## running

### run in VICE

```
xvic -memory unexpanded 2up11.prg
```

or load it from the BASIC prompt:

```
load "2up11.prg",8
run
```

### run on real hardware

Copy the PRG to a disk image or transfer it using your preferred method (SD2IEC, Pi1541, etc.). The game requires no RAM expansion.

## development notes

Additional technical notes, PETSCII layout sketches, and memory usage details can be found in the `docs` folder. These files are optional and may grow as the project evolves.

## automatic build

When a pull request containing changes to any `.bas` file is merged, the GitHub Action in `.github/workflows/build-prg.yml` automatically:

- copies the repo’s `tools/petcat` executable into the action runner  
- runs `petcat` to generate the `.prg` file  
- writes the resulting `.prg` file into the `prgs` folder  
- commits the generated file back to the main branch  

This keeps the PRG output synchronized with the BASIC source without installing the full VICE package.

## license

This project is released under the MIT License. See the `LICENSE` file for details.
