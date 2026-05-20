' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0          : N = number of patterns (1..255)
'   byte 1..N*3     : for each pattern: WORD big-endian absolute offset + BYTE row_count
'   row data        : [div, idx, stepHi, stepLo, waveId, stutterMode, 0, 0] x row_count
'                     idx=$FF        = random chunk chosen at runtime
'                     waveId=$FF     = random wave chosen at runtime (0..4)
'                     waveId=0       = default (backward compatible with old patterns)
'                     stutterMode=$00 = no stutter, 1x (default, backward compatible)
'                     stutterMode=$01 = stutter 2x
'                     stutterMode=$02 = stutter 4x
'                     stutterMode=$03 = stutter 8x
'                     stutterMode=$FF = random stutter chosen at runtime (1x/2x/4x)
'                     byte 6..7 reserved for future use
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
