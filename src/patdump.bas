' =============================================================================
' patdump.bas - debug: legge patterns.bin dal banco e stampa ogni nota
' =============================================================================

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' Variabili in RAM sicura (sotto $6000)
DIM gPatBank  (1) AS BYTE FOR BANK READ : GLOBAL gPatBank
DIM gPatPtr   (2) AS BYTE FOR BANK READ : GLOBAL gPatPtr   : ' ADDRESS hi/lo
DIM gNoteDiv  (1) AS BYTE FOR BANK READ : GLOBAL gNoteDiv
DIM gNoteIdx  (1) AS BYTE FOR BANK READ : GLOBAL gNoteIdx
DIM gNoteShi  (1) AS BYTE FOR BANK READ : GLOBAL gNoteShi
DIM gNoteSlo  (1) AS BYTE FOR BANK READ : GLOBAL gNoteSlo

' =============================================================================
' READ_NOTE_ASM
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
gPatBank(0) = VARBANK(patFile)
DIM tmp AS ADDRESS
tmp        = VARBANKPTR(patFile)
gPatPtr(0) = tmp / 256
gPatPtr(1) = tmp AND $FF
CALL read_note_asm

DIM nPat       AS BYTE    : nPat       = gNoteDiv(0)
DIM offHi      AS BYTE    : offHi      = gNoteIdx(0)
DIM offLo      AS BYTE    : offLo      = gNoteShi(0)
DIM pat1Off    AS INTEGER : pat1Off    = offHi * 256 + offLo
DIM fileSize   AS INTEGER : fileSize   = SIZE(patFile)
DIM totalNotes AS INTEGER : totalNotes = (fileSize - pat1Off) / 4
DIM basePtr    AS ADDRESS : basePtr    = VARBANKPTR(patFile) + pat1Off

PRINT "bank    : "; gPatBank(0)
PRINT "fileSize: "; fileSize
PRINT "nPat    : "; nPat
PRINT "pat1Off : "; pat1Off
PRINT "nNotes  : "; totalNotes
PRINT ""

DIM n AS INTEGER
FOR n = 0 TO totalNotes - 1
    tmp        = basePtr + n * 4
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_note_asm
    PRINT n; ": div="; gNoteDiv(0); " idx="; gNoteIdx(0); " shi="; gNoteShi(0); " slo="; gNoteSlo(0)
NEXT n

PRINT ""
PRINT "done."
