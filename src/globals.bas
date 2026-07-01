' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0          : N = number of patterns (1..255)
'   byte 1..N*3     : for each pattern: WORD big-endian absolute offset + BYTE row_count
'   row data        : [div, idx, stepHi, stepLo, waveId, stutterMode, 0, 0] x row_count
'                     idx=$FF         = random chunk chosen at runtime
'                     waveId=$FF      = random wave chosen at runtime (0..4)
'                     waveId=0        = default (backward compatible with old patterns)
'                     stutterMode=$00 = no stutter, 1x (default, backward compatible)
'                     stutterMode=$01 = stutter x2, flat pitch
'                     stutterMode=$02 = stutter x4, flat pitch
'                     stutterMode=$03 = stutter x8, flat pitch
'                     stutterMode=$04 = stutter x2, pitch up +1 semi/rep
'                     stutterMode=$05 = stutter x4, pitch up +1 semi/rep
'                     stutterMode=$06 = stutter x2, pitch up +2 semi/rep
'                     stutterMode=$07 = stutter x4, pitch up +2 semi/rep
'                     stutterMode=$08 = stutter x2, pitch down -1 semi/rep
'                     stutterMode=$09 = stutter x4, pitch down -1 semi/rep
'                     stutterMode=$0A = stutter x2, pitch down -2 semi/rep
'                     stutterMode=$0B = stutter x4, pitch down -2 semi/rep
'                     stutterMode=$FF = random stutter chosen at runtime (sm 0..11)
'                     byte 6..7 reserved for future use
'
' stepDelta 8.8 values used by stutterDeltaHi/Lo:
'   semi  0 -> $0100 (x1.000000)
'   semi +1 -> $010F (x1.058594, exact 2^(1/12)=1.059463)
'   semi +2 -> $011F (x1.121094, exact 2^(2/12)=1.122462)
'   semi -1 -> $00F2 (x0.945312, exact 2^(-1/12)=0.943874)
'   semi -2 -> $00E4 (x0.890625, exact 2^(-2/12)=0.890899)
' =============================================================================

' --- Banked assets ---
GLOBAL wave
wave  := LOAD("assets/amen150.bin") BANKED
GLOBAL wave2
wave2 := LOAD("assets/chords.bin") BANKED
GLOBAL wave3
wave3 := LOAD("assets/reverse.bin") BANKED
GLOBAL wave4
wave4 := LOAD("assets/future.bin") BANKED
GLOBAL wave5
wave5 := LOAD("assets/606.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- Wave lookup tables (precalculated by init_waves) ---
DIM waveAddress(5) AS WORD : GLOBAL waveAddress  :' base address of each wave
DIM wavBank(5)     AS BYTE : GLOBAL wavBank      :' bank number of each wave

' --- WAV player ASM interface (below $6000, safe from bank swap) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Total pattern count (set by init_patterns) ---
DIM gNPat      (1) AS BYTE : GLOBAL gNPat   :' number of patterns in the file

' --- Current pattern: absolute offset and row count (set by load_pattern) ---
DIM gPatOffset AS INTEGER  : GLOBAL gPatOffset  :' absolute offset into the file
DIM gNRows     AS BYTE     : GLOBAL gNRows       :' number of rows in current pattern

' --- Single row buffer (8 bytes), read one row at a time during play_pattern ---
DIM gRow (8) AS BYTE FOR BANK READ : GLOBAL gRow

' --- Stutter lookup tables (init by init_stutter) ---
' sm 0..11, $FF = RND
DIM stutterReps    (12) AS BYTE : GLOBAL stutterReps     :' repetitions per mode
DIM stutterDeltaHi (12) AS BYTE : GLOBAL stutterDeltaHi  :' 8.8 pitch delta, hi byte
DIM stutterDeltaLo (12) AS BYTE : GLOBAL stutterDeltaLo  :' 8.8 pitch delta, lo byte

' --- Pattern change flag ---
' Set to 1 by handle_key when 1-9/N/P is pressed during playback.
' Causes play_pattern to exit immediately after the current row.
' Reset to 0 by main.bas at the start of each play cycle.
DIM gPatChanged AS BYTE : GLOBAL gPatChanged


' =============================================================================
' INIT_WAVES
' Precalculates base address and bank number for each wave.
' Must be called once at startup, before any call to play_note.
' =============================================================================
PROCEDURE init_waves
    waveAddress(0) = VARBANKPTR(wave)  : wavBank(0) = VARBANK(wave)
    waveAddress(1) = VARBANKPTR(wave2) : wavBank(1) = VARBANK(wave2)
    waveAddress(2) = VARBANKPTR(wave3) : wavBank(2) = VARBANK(wave3)
    waveAddress(3) = VARBANKPTR(wave4) : wavBank(3) = VARBANK(wave4)
    waveAddress(4) = VARBANKPTR(wave5) : wavBank(4) = VARBANK(wave5)
END PROC


' =============================================================================
' INIT_STUTTER
' Populates stutterReps and stutterDelta lookup tables.
' Must be called once at startup, before any call to play_note_stutter.
'
' sm  reps  delta     effect
'  0    1   $0100     normal (no stutter)
'  1    2   $0100     stutter x2, flat
'  2    4   $0100     stutter x4, flat
'  3    8   $0100     stutter x8, flat
'  4    2   $010F     x2 pitch up +1 semi/rep
'  5    4   $010F     x4 pitch up +1 semi/rep
'  6    2   $011F     x2 pitch up +2 semi/rep
'  7    4   $011F     x4 pitch up +2 semi/rep
'  8    2   $00F2     x2 pitch down -1 semi/rep
'  9    4   $00F2     x4 pitch down -1 semi/rep
' 10    2   $00E4     x2 pitch down -2 semi/rep
' 11    4   $00E4     x4 pitch down -2 semi/rep
' =============================================================================
PROCEDURE init_stutter
    stutterReps(0)=1  : stutterReps(1)=2  : stutterReps(2)=4  : stutterReps(3)=8
    stutterReps(4)=2  : stutterReps(5)=4  : stutterReps(6)=2  : stutterReps(7)=4
    stutterReps(8)=2  : stutterReps(9)=4  : stutterReps(10)=2 : stutterReps(11)=4

    stutterDeltaHi(0)=1  : stutterDeltaHi(1)=1  : stutterDeltaHi(2)=1  : stutterDeltaHi(3)=1
    stutterDeltaHi(4)=1  : stutterDeltaHi(5)=1  : stutterDeltaHi(6)=1  : stutterDeltaHi(7)=1
    stutterDeltaHi(8)=0  : stutterDeltaHi(9)=0  : stutterDeltaHi(10)=0 : stutterDeltaHi(11)=0

    stutterDeltaLo(0)=0    : stutterDeltaLo(1)=0    : stutterDeltaLo(2)=0    : stutterDeltaLo(3)=0
    stutterDeltaLo(4)=$0F  : stutterDeltaLo(5)=$0F  : stutterDeltaLo(6)=$1F  : stutterDeltaLo(7)=$1F
    stutterDeltaLo(8)=$F2  : stutterDeltaLo(9)=$F2  : stutterDeltaLo(10)=$E4 : stutterDeltaLo(11)=$E4
END PROC


' --- Tempo control ---
DIM gPlaybackDelay (1) AS BYTE FOR BANK READ : GLOBAL gPlaybackDelay  :' delay between samples
DIM gTempoFactor   AS BYTE : GLOBAL gTempoFactor  :' tempo multiplier (128=normal)

' Inizializza in INIT_TEMPO (nuova procedura)
PROCEDURE init_tempo
    gPlaybackDelay(0) = 24  :' default delay per ~8kHz
    gTempoFactor = 128      :' normal speed
END PROC