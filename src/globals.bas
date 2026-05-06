' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0          : N = number of patterns (1..255)
'   byte 1..N*3     : per ogni pattern: WORD big-endian offset assoluto + BYTE row_count
'   dati righe      : [div, idx, stepHi, stepLo, 0, 0, 0, 0] x row_count
'                     idx=$FF = random chunk
'                     ultimi 4 byte riservati per effetti futuri
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

' --- Contatore pattern totali (letto da init_patterns) ---
DIM gNPat    (1) AS BYTE : GLOBAL gNPat   :' numero pattern nel file

' --- Pattern corrente: offset e numero righe (letti da load_pattern) ---
DIM gPatOffset AS INTEGER : GLOBAL gPatOffset  :' offset assoluto nel file
DIM gNRows     AS BYTE    : GLOBAL gNRows       :' numero righe del pattern corrente

' --- Buffer singola riga (8 byte) letta riga per riga durante play_pattern ---
DIM gRow (8) AS BYTE FOR BANK READ : GLOBAL gRow
