' =============================================================================
' prove.bas - test isolato read_header + play_pattern
' Fix: lettura gPatternOffset con tmpHi/tmpLo espliciti
' per evitare il bug di ugBASIC su * 256 + lo.
' =============================================================================

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

DIM gPatBank (1) AS BYTE FOR BANK READ : GLOBAL gPatBank
DIM gPatPtr  (2) AS BYTE FOR BANK READ : GLOBAL gPatPtr
DIM gNoteDiv (1) AS BYTE FOR BANK READ : GLOBAL gNoteDiv
DIM gNoteIdx (1) AS BYTE FOR BANK READ : GLOBAL gNoteIdx
DIM gNoteShi (1) AS BYTE FOR BANK READ : GLOBAL gNoteShi
DIM gNoteSlo (1) AS BYTE FOR BANK READ : GLOBAL gNoteSlo

DIM gNPat          (1)   AS BYTE FOR BANK READ : GLOBAL gNPat
DIM gPatternOffset (514) AS BYTE FOR BANK READ : GLOBAL gPatternOffset
DIM gCurPat        (1)   AS BYTE FOR BANK READ : GLOBAL gCurPat

' =============================================================================
PROC read_byte_asm
    ON CPU6809 BEGIN ASM
        LDA   _gPatBank
        STA   $A7E5
        LDX   _gPatPtr
        LDA   0,X
        STA   _gNoteDiv
        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC

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

' =============================================================================
PROC read_header
    DIM i       AS BYTE
    DIM hiB     AS BYTE
    DIM loB     AS BYTE
    DIM fileOff AS INTEGER
    DIM ramAddr AS ADDRESS
    DIM tmp     AS ADDRESS
    DIM base    AS ADDRESS
    DIM slotIdx AS INTEGER

    gPatBank(0) = VARBANK(patFile)
    base        = VARBANKPTR(patFile)

    ' Leggi N (byte 0)
    tmp        = base
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    gNPat(0) = gNoteDiv(0)

    FOR i = 1 TO gNPat(0)
        ' Leggi hi byte dell'offset
        tmp        = base + 1 + (i - 1) * 2
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_byte_asm
        hiB = gNoteDiv(0)

        ' Leggi lo byte dell'offset
        tmp        = tmp + 1
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_byte_asm
        loB = gNoteDiv(0)

        fileOff = hiB * 256 + loB
        ramAddr = base + fileOff

        ' Scrivi in gPatternOffset con tmpHi/tmpLo espliciti
        slotIdx = (i - 1) * 2
        DIM whiB AS BYTE : whiB = ramAddr / 256
        DIM wloB AS BYTE : wloB = ramAddr AND $FF
        gPatternOffset(slotIdx)     = whiB
        gPatternOffset(slotIdx + 1) = wloB
    NEXT i

    ' Sentinella N+1
    ramAddr = base + SIZE(patFile)
    slotIdx = gNPat(0) * 2
    DIM shiB AS BYTE : shiB = ramAddr / 256
    DIM sloB AS BYTE : sloB = ramAddr AND $FF
    gPatternOffset(slotIdx)     = shiB
    gPatternOffset(slotIdx + 1) = sloB

    gCurPat(0) = 1
END PROC

' =============================================================================
' MAIN - stampa header, poi stampa le prime 2 note del pattern 1
' =============================================================================
CALL read_header

PRINT "N patterns: "; gNPat(0)
PRINT ""

DIM i       AS BYTE
DIM slotIdx AS INTEGER
DIM tmpHi   AS BYTE
DIM tmpLo   AS BYTE
DIM a0      AS ADDRESS
DIM a1      AS ADDRESS
DIM tot     AS INTEGER
DIM tmp     AS ADDRESS
DIM n       AS INTEGER

FOR i = 1 TO gNPat(0)
    ' Leggi baseAddr con tmpHi/tmpLo
    slotIdx = (i - 1) * 2
    tmpHi = gPatternOffset(slotIdx)
    tmpLo = gPatternOffset(slotIdx + 1)
    a0 = tmpHi * 256 + tmpLo

    ' Leggi nextAddr con tmpHi/tmpLo
    slotIdx = i * 2
    tmpHi = gPatternOffset(slotIdx)
    tmpLo = gPatternOffset(slotIdx + 1)
    a1 = tmpHi * 256 + tmpLo

    tot = (a1 - a0) / 4

    PRINT "PAT "; i; " addr="; a0; " notes="; tot

    ' Stampa le prime 2 note (o meno se tot < 2)
    DIM maxN AS INTEGER : maxN = tot
    IF maxN > 2 THEN maxN = 2
    FOR n = 0 TO maxN - 1
        tmp        = a0 + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        PRINT " note "; n; ": DIV="; gNoteDiv(0); " IDX="; gNoteIdx(0); " SHI="; gNoteShi(0); " SLO="; gNoteSlo(0)
    NEXT n
NEXT i

PRINT ""
PRINT "OK - press any key"
WAIT KEY
