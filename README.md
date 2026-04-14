# olibreakbeats

**Thomson MO6 generative breakbeat drum machine**
Written in UGBasic + Motorola 6809 assembly.

---

## Concept

A minimal drum machine for the Thomson MO6 (1984, CPU 6809 @ 1 MHz, 6-bit DAC).
Loads a single breakbeat sample (Amen-style), slices it into equal chunks, and plays
them back in generative patterns inspired by 90s jungle/breakbeat aesthetics.

```
UGBasic (sequencer + generative pattern logic)
    │
    └── ASM PLAY_CHUNK (6809, ~125 cycles/sample → ~8kHz)
              │
              └── DAC output → $A7CD (PIA port B, bits 0–5)
```

## How it works

1. A raw PCM sample (`amen1.dat`) is loaded into memory at startup
2. The sample is divided into N equal **chunks** (4, 8, or 16 slices)
3. A **pattern array** of 16 slots selects which chunk plays at each beat
4. The ASM **PLAY_CHUNK** routine outputs each chunk to the DAC with calibrated timing
5. An optional **step parameter** (8.8 fixed-point) shifts pitch inside a fixed time slot
6. A **LFSR 16-bit** generator mutates the pattern every N loops (generative mode)

## Milestones

| Step | Status | Description |
|------|--------|-------------|
| 1 | 🔨 WIP | ASM player, fixed step `$0100`, timing calibrated to ~8kHz |
| 2 | ⬜ | Variable step parameter — pitch up/down on single chunk |
| 3 | ⬜ | UGBasic sequencer with `PATTERN[16]` array, static patterns |
| 4 | ⬜ | LFSR generative mutations (swap, stutter, pitch random) |
| 5 | ⬜ | Custom Amen break sample — 16 balanced chunks (kick/snare/hihat) |

## File structure

```
olibreakbeats/
├── README.md
├── SPEC.md                  ← technical specification
├── proto/
│   ├── drum_proto.bas       ← UGBasic prototype (Passo 1)
│   └── player_core.asm      ← standalone 6809 ASM player reference
└── docs/
    └── architecture.md      ← design decisions and layer diagram
```

## Hardware target

| Property | Value |
|---|---|
| Computer | Thomson MO6 |
| CPU | Motorola 6809 @ 1 MHz |
| DAC | 6-bit, PIA port B (`$A7CD` / `$A7CF`), bits 0–5 |
| Target sample rate | ~8000 Hz (125 CPU cycles/sample) |
| Sample format | 8-bit unsigned PCM, mono, 8 kHz |
| RAM | 128 KB |

## Tools

- [ugBASIC](https://ugbasic.iwashere.eu/) — cross-compiler targeting MO6
- [MAME](https://www.mamedev.org/) — emulation and cycle-accurate testing

## Sample preparation

Convert any WAV to the required raw format with ffmpeg:

```bash
ffmpeg -i source.wav -ar 8000 -ac 1 -f u8 amen1.dat
```

A 1-bar loop at 160 BPM = ~0.375 s → ~3000 bytes.
Two bars fit in ~6 KB — well within the MO6's 128 KB RAM.
