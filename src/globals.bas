' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0        : N = number of patterns (1..255)
'   byte 1..2     : offset pattern 1 (big-endian WORD, relativo a byte 0)
'   byte 3..4     : offset pattern 2
'   ...
'   dati note     : [div, idx, stepHi, stepLo] x N
'                   idx=$FF = random chunk
' =============================================================================

' --- Banked assets ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- WAV player ASM interface (sotto $6000, safe from bank swap) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Contatore pattern (letto da file all avvio) ---
DIM gNPat   (1) AS BYTE FOR BANK READ : GLOBAL gNPat
DIM gCurPat (1) AS BYTE FOR BANK READ : GLOBAL gCurPat

' --- Pattern corrente in RAM normale ---
DIM gPat    (64) AS BYTE : GLOBAL gPat    :' max 16 note x 4 byte
DIM gNNotes (1)  AS BYTE : GLOBAL gNNotes :' numero note nel pattern corrente
