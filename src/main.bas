' =============================================================================
' olibreakbeats - main.bas   v0.8
' Thomson MO6 / ugBASIC / Motorola 6809
'
' Pattern-driven generative breakbeat player.
' Reads patterns.bin directly from banked RAM via ASM (no buffer).
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
'
' Step 8.8 fixed-point pitch:
'   $0100 = 1.0x  original pitch
'   $0200 = 2.0x  octave up
'   $0180 = 1.5x  fifth up
'   $0080 = 0.5x  octave down
' =============================================================================


INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"



' =============================================================================
' Main
' =============================================================================
CALL init_dac

' --- Parse patterns.bin header from banked RAM ---
' Reuse read_note_asm: first 4 bytes are N | off_hi | off_lo | (ignored)
gPatBank(0) = VARBANK(patFile)
DIM tmp     AS ADDRESS : tmp = VARBANKPTR(patFile)
gPatPtr(0)  = tmp / 256
gPatPtr(1)  = tmp AND $FF
CALL read_note_asm

DIM nPat       AS BYTE    : nPat       = gNoteDiv(0)               :' number of patterns
DIM offHi      AS BYTE    : offHi      = gNoteIdx(0)               :' pattern 1 offset high
DIM offLo      AS BYTE    : offLo      = gNoteShi(0)               :' pattern 1 offset low
DIM pat1Off    AS INTEGER : pat1Off    = offHi * 256 + offLo       :' absolute offset
DIM fileSize   AS INTEGER : fileSize   = SIZE(patFile)
DIM totalNotes AS INTEGER : totalNotes = (fileSize - pat1Off) / 4  :' notes in pattern 1
DIM basePtr    AS ADDRESS : basePtr    = VARBANKPTR(patFile) + pat1Off

DIM n AS INTEGER


' --- Main loop: play pattern 1 forever ---
DO
    FOR n = 0 TO totalNotes - 1
        tmp        = basePtr + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        play_note[gNoteIdx(0), gNoteDiv(0), gNoteShi(0), gNoteSlo(0)]
    NEXT n
LOOP
