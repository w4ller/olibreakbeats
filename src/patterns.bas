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
' DEBUG: offset calcolato in INTEGER prima di sommare a base ADDRESS
' =============================================================================
PROCEDURE load_pattern[patIdx AS BYTE]
    DIM base   AS ADDRESS
    DIM tmp    AS ADDRESS
    DIM offset AS INTEGER
    DIM hiB    AS INTEGER

    gPatBank(0) = VARBANK(patFile)
    base        = VARBANKPTR(patFile)

    offset     = (patIdx - 1) * 2 + 1
    tmp        = base + offset
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    hiB = gNoteDiv(0)
END PROC


' =============================================================================
' PLAY_PATTERN
' =============================================================================
PROCEDURE play_pattern
    DIM n AS BYTE
    FOR n = 0 TO gNNotes(0) - 1
        play_note[gPat(n*4), gPat(n*4+1), gPat(n*4+2), gPat(n*4+3)]
    NEXT n
END PROC
