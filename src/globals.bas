' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' *** IMPORTANT - BANK SWAP MEMORY RULE ***
' Any variable read or written during a bank swap MUST live below $6000.
' The region $6000-$7FFF is the banked window: switching banks remaps it,
' corrupting any variables stored there.
' Rule:
'   1-byte vars  -> DIM x(1) AS BYTE FOR BANK READ : GLOBAL x
'   2-byte vars  -> DIM x(2) AS BYTE FOR BANK READ : GLOBAL x  (hi=x(0), lo=x(1))
' All ASM interface globals below follow this rule.
'
' patterns.bin format:
'   byte 0        : N = number of patterns (1..255)
'   byte 1..2     : absolute offset of pattern 1 (big-endian WORD)
'   byte 3..4     : absolute offset of pattern 2 (if N>1)
'   ...
'   data section  : notes, 4 bytes each: DIV  IDX  STEP_HI  STEP_LO
'                   IDX=$FF = random chunk (0..DIV-1) chosen at runtime
' =============================================================================

' --- Banked assets ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED


' --- WAV player ASM interface (all below $6000, safe from bank swap) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase  :' ADDRESS hi/lo
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize :' INTEGER hi/lo
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Pattern reader ASM interface (all below $6000, safe from bank swap) ---
DIM gPatBank   (1) AS BYTE FOR BANK READ : GLOBAL gPatBank
DIM gPatPtr    (2) AS BYTE FOR BANK READ : GLOBAL gPatPtr    :' ADDRESS hi/lo
DIM gNoteDiv   (1) AS BYTE FOR BANK READ : GLOBAL gNoteDiv
DIM gNoteIdx   (1) AS BYTE FOR BANK READ : GLOBAL gNoteIdx
DIM gNoteShi   (1) AS BYTE FOR BANK READ : GLOBAL gNoteShi
DIM gNoteSlo   (1) AS BYTE FOR BANK READ : GLOBAL gNoteSlo

' --- Pattern offset table (precalcolato da read_header, sotto $6000) ---
DIM gNPat          (1)   AS BYTE FOR BANK READ : GLOBAL gNPat
DIM gPatternOffset (514) AS BYTE FOR BANK READ : GLOBAL gPatternOffset
DIM gCurPat        (1)   AS BYTE FOR BANK READ : GLOBAL gCurPat

' --- Pattern corrente in RAM normale ---
DIM gPat    (64) AS BYTE : GLOBAL gPat     :' max 16 note x 4 byte
DIM gNNotes (1)  AS BYTE : GLOBAL gNNotes  :' numero note nel pattern corrente
