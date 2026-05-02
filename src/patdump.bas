' =============================================================================
' patdump.bas - debug: legge patterns.bin dal banco e stampa ogni nota
' =============================================================================

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

DIM gPatBank AS BYTE    : GLOBAL gPatBank
DIM gPatPtr  AS ADDRESS : GLOBAL gPatPtr
DIM gNoteDiv AS BYTE    : GLOBAL gNoteDiv
DIM gNoteIdx AS BYTE    : GLOBAL gNoteIdx
DIM gNoteShi AS BYTE    : GLOBAL gNoteShi
DIM gNoteSlo AS BYTE    : GLOBAL gNoteSlo

' =============================================================================
' READ_NOTE_ASM - legge 4 byte da gPatPtr nel banco gPatBank
' =============================================================================
PROC read_note_asm
    ON CPU6809 BEGIN ASM
        LDA   _gPatBank
        STA   $A7E5
        LDX   _gPatPtr
        LDA   0,X
        STA   _gNoteDiv
        LDA   1,X
        STA   _gNoteIdx
        LDA   2,X
        STA   _gNoteShi
        LDA   3,X
        STA   _gNoteSlo
        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC

' --- Setup ---
gPatBank = VARBANK(patFile)

' --- Leggi byte 0..3 (header: N, off_hi, off_lo, _) ---
gPatPtr = VARBANKPTR(patFile)
CALL read_note_asm

DIM nPat       AS BYTE    : nPat       = gNoteDiv
DIM offHi      AS BYTE    : offHi      = gNoteIdx
DIM offLo      AS BYTE    : offLo      = gNoteShi
DIM pat1Off    AS INTEGER : pat1Off    = offHi * 256 + offLo
DIM fileSize   AS INTEGER : fileSize   = SIZE(patFile)
DIM totalNotes AS INTEGER : totalNotes = (fileSize - pat1Off) / 4
DIM basePtr    AS ADDRESS : basePtr    = VARBANKPTR(patFile) + pat1Off

PRINT "bank    : "; gPatBank
PRINT "fileSize: "; fileSize
PRINT "nPat    : "; nPat
PRINT "pat1Off : "; pat1Off
PRINT "nNotes  : "; totalNotes
PRINT ""

' --- Stampa ogni nota ---
DIM n AS INTEGER
FOR n = 0 TO totalNotes - 1
    gPatPtr = basePtr + n * 4
    CALL read_note_asm
    PRINT n; ": div="; gNoteDiv; " idx="; gNoteIdx; " shi="; gNoteShi; " slo="; gNoteSlo
NEXT n

PRINT ""
PRINT "done."
