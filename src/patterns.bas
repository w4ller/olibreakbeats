' =============================================================================
' patterns.bas - pattern reader and sequencer
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
' LOAD_PATTERN[patIdx]
' Legge il pattern patIdx da patterns.bin (banked) e lo copia in gPat.
' Imposta gNNotes(0) con il numero di note.
' patIdx e 1-based.
'
' patterns.bin layout:
'   byte 0       : N pattern
'   byte 1..2    : offset pattern 1 (big-endian, relativo a byte 0)
'   byte 3..4    : offset pattern 2
'   ...
'   dati note    : [div, idx, stepHi, stepLo] x N
' =============================================================================
PROCEDURE load_pattern[patIdx AS BYTE]
    DIM base    AS ADDRESS
    DIM tmp     AS ADDRESS
    DIM hiB     AS INTEGER
    DIM loB     AS INTEGER
    DIM offA    AS INTEGER
    DIM offB    AS INTEGER
    DIM nNotes  AS BYTE
    DIM i       AS BYTE

    gPatBank(0) = VARBANK(patFile)
    base        = VARBANKPTR(patFile)

    ' Leggi offset di patIdx
    tmp        = base + 1 + (patIdx - 1) * 2
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    hiB = gNoteDiv(0)

    tmp        = tmp + 1
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    loB = gNoteDiv(0)

    offA = hiB * 256 + loB

    ' Leggi offset del pattern successivo (sentinella = fine file se ultimo)
    tmp        = base + 1 + patIdx * 2
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    hiB = gNoteDiv(0)

    tmp        = tmp + 1
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    loB = gNoteDiv(0)

    offB = hiB * 256 + loB

    ' Se patIdx e l'ultimo, offB potrebbe essere 0 -> usa SIZE(patFile)
    IF offB = 0 THEN
        offB = SIZE(patFile)
    END IF

    nNotes = (offB - offA) / 4
    IF nNotes > 16 THEN nNotes = 16   ' protezione overflow gPat
    gNNotes(0) = nNotes

    ' Copia le note in gPat byte per byte
    FOR i = 0 TO nNotes * 4 - 1
        tmp        = base + offA + i
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_byte_asm
        gPat(i) = gNoteDiv(0)
    NEXT i
END PROC


' =============================================================================
' PLAY_PATTERN
' Suona gNNotes note dall'array globale gPat.
' Formato: [div, idx, stepHi, stepLo] x gNNotes
' =============================================================================
PROCEDURE play_pattern
    DIM n AS BYTE
    FOR n = 0 TO gNNotes(0) - 1
        play_note[gPat(n*4), gPat(n*4+1), gPat(n*4+2), gPat(n*4+3)]
    NEXT n
END PROC
