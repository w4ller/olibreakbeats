# olibreakbeats — Technical Specification

## 1. Hardware

### 1.1 CPU
- Motorola 6809, 1 MHz clock
- 1 CPU cycle = 1 µs

### 1.2 DAC — Thomson MO6

The MO6 has no dedicated sound chip. Audio is output through a 6-bit DAC
wired to bits 0–5 of PIA port B.

| Register | Address | Role |
|---|---|---|
| PIA control B | `$A7CF` | Configure DDRB / port mode |
| PIA data B | `$A7CD` | Write sample byte to DAC |

**Initialisation sequence** (from `drum.bas`):
```
LDA  $A7CF    ; read control register
ANDA #$FB     ; clear bit 2 → select DDR mode
STA  $A7CF
LDB  #$3F     ; bits 0–5 as outputs (DAC lines)
STB  $A7CD
ORA  #$04     ; set bit 2 → select port mode
STA  $A7CF
```

**Writing a sample:** write the 8-bit value (top 6 bits used) to `$A7CD`.

---

## 2. Sample format

| Property | Value |
|---|---|
| Encoding | 8-bit unsigned PCM |
| Channels | Mono |
| Sample rate | 8000 Hz |
| File | `amen1.dat` (raw, no header) |

Convert from WAV:
```bash
ffmpeg -i source.wav -ar 8000 -ac 1 -f u8 amen1.dat
```

**Size budget:** 1 bar at 160 BPM ≈ 3000 bytes. 2 bars ≈ 6 KB.

---

## 3. Chunking model

The sample is divided into **N equal chunks** where N ∈ {4, 8, 16}.

```
chunk_size  = wave_length / N          (integer bytes)
chunk_start = wave_base + idx * chunk_size
```

Each chunk is addressed by a `(chunkIdx, chunkDiv)` pair:
- `chunkDiv` = N (4, 8, or 16)
- `chunkIdx` = 0 … N-1

A single chunk at 8kHz, N=16, 3000-byte sample = ~188 samples ≈ 23 ms per slot.

---

## 4. ASM player — PLAY_CHUNK

### 4.1 Purpose

Play exactly `chunk_size` samples to the DAC at a calibrated rate (~8kHz),
using a fixed output count and variable read step.

### 4.2 Interface (global variables, set by BASIC before call)

| Variable | Type | Description |
|---|---|---|
| `gWaveBase` | ADDRESS (word) | Start address of the chunk in RAM |
| `gChunkSize` | INTEGER (word) | Number of output samples to emit |
| `gStepHi` | BYTE | Integer part of read step (8.8 fixed-point) |
| `gStepLo` | BYTE | Fractional part of read step |
| `gFracAcc` | BYTE | Fractional accumulator (reset to 0 before each chunk) |

### 4.3 Algorithm

```
X ← gWaveBase          ; read pointer
Y ← gChunkSize         ; output counter (FIXED — determines duration)
gFracAcc ← 0

loop:
    DAC ← mem[X]       ; output current sample
    <delay N cycles>   ; calibrate to ~8kHz
    
    ; fixed-point advance:  pointer += step (8.8)
    gFracAcc += gStepLo           ; add fractional part, carry → C
    X += gStepHi + C              ; advance integer part + carry

    Y -= 1
    if Y ≠ 0 → loop
```

**Key property:** Y is never affected by the step value.
Duration = `gChunkSize × T_cycle` = constant regardless of pitch.

### 4.4 Cycle budget (1 MHz, target 8000 Hz → 125 cycles/sample)

| Block | Instructions | Cycles |
|---|---|---|
| DAC output | `LDA 0,X` + `STA $A7CD` | 4 + 5 = **9** |
| Delay loop (B=17) | `LDB #17` + 17×(`DECB`+`BNE`) | 2 + 84 = **86** |
| Fixed-point advance | `LDB` + `ADDB` + `STB` + `LDB` + `ADCB #0` + `ABX` | 4+4+4+4+2+3 = **21** |
| Counter + branch | `LEAY -1,Y` + `BNE` | 5 + 3 = **8** |
| **Total** | | **≈ 124** |

> Tune the delay constant (B) between 16–18 to centre exactly on 8000 Hz.
> Each unit of B adds/removes 5 cycles.

### 4.5 Fixed-point step table (8.8 format: `$HHLL`)

| Step (hex) | Factor | Musical interval |
|---|---|---|
| `$0080` | 0.5× | Octave down |
| `$00C0` | 0.75× | ~Perfect fourth down |
| `$00E0` | 0.875× | ~Major second down |
| `$0100` | 1.0× | Original pitch |
| `$0120` | 1.125× | ~Major second up |
| `$0180` | 1.5× | ~Perfect fifth up |
| `$0200` | 2.0× | Octave up |

### 4.6 Side effects of pitch shift

- `step > 1.0`: reads into (and potentially past) the chunk; tail is silence/garbage.
  → Pass a proportionally larger `gChunkSize` to compensate, or accept the truncation
    as a stylistic feature (authentic jungle/DnB stutter).
- `step < 1.0`: only the first portion of the chunk is heard, repeated/slowed.

---

## 5. Sequencer data structure (Passo 3)

```
PATTERN_CHUNK(0..15)  AS INTEGER   ' chunk index for each beat slot
PATTERN_DIV(0..15)    AS INTEGER   ' chunk divisor for each beat slot
PATTERN_STEPH(0..15)  AS BYTE      ' step high byte for each slot
PATTERN_STEPL(0..15)  AS BYTE      ' step low byte for each slot
```

One pattern = 16 slots. Each slot plays one chunk at one pitch.
The sequencer loops `FOR beat = 0 TO 15`, loads the four params, and calls PLAY_CHUNK.

---

## 6. Generative mutations — LFSR

A 16-bit Galois LFSR (polynomial x¹⁶ + x¹⁵ + x¹³ + x⁴ + 1) provides
pseudo-random values at ~10 CPU cycles per call.

```asm
LFSR_NEXT:
    LDD   LFSR_STATE    ; D = current state (must be ≠ 0)
    LSRB                ; shift right LSB → carry
    RORA                ; shift A right, carry in from MSB
    BCC   LFSR_DONE     ; no feedback if shifted bit was 0
    EORA  #$B4          ; feedback taps: bits 15, 13 (high byte)
    EORB  #$10          ; feedback tap:  bit 4  (low byte)
LFSR_DONE:
    STD   LFSR_STATE
    RTS                 ; A = random high byte, B = random low byte
```

**Mutation types** (applied every N loops):

| Mutation | Effect | Probability |
|---|---|---|
| Slot swap | Exchange two random beat slots | 40% |
| Stutter | Repeat one slot at 32nd-note resolution | 30% |
| Pitch hit | Change step of one slot to a non-1.0 value | 20% |
| Reset | Restore original base pattern | 10% |

---

## 7. Development milestones

### Passo 1 — ASM player (current)
- File: `proto/drum_proto.bas`
- STEP fixed at `$0100`
- Verify clean audio output and correct timing on MAME

### Passo 2 — Variable pitch
- Add `gStepHi` / `gStepLo` as real parameters in `play_note`
- Test `$0200` (octave up), `$0080` (octave down) on a single chunk

### Passo 3 — Static sequencer
- Introduce `PATTERN_*` arrays
- Port the existing hardcoded pattern calls to array-driven loop

### Passo 4 — Generative mode
- Implement LFSR in ASM
- Add mutation logic in BASIC, triggered every 4 pattern loops

### Passo 5 — Custom sample
- Design Amen-style break specifically for 16-chunk slicing
- Each chunk = one distinct drum hit (kick, snare, open HH, closed HH, ghost)
