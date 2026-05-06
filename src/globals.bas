' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0          : N = number of patterns (1..255)
'   byte 1..N*3     : for each pattern: WORD big-endian absolute offset + BYTE row_count
'   row data        : [div, idx, stepHi, stepLo, 0, 0, 0, 0] x row_count
'                     idx=$FF = random chunk chosen at runtime
'                     last 4 bytes reserved for future use
' =============================================================================

' --- Banked assets ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

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
