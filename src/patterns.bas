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
' PLAY_PATTERN
' Legge gNNotes note dall'array globale gPat.
' Formato: [idx, div, stepHi, stepLo] x gNNotes
' =============================================================================
PROCEDURE play_pattern
    DIM n AS BYTE
    FOR n = 0 TO gNNotes(0) - 1
        play_note[gPat(n*4), gPat(n*4+1), gPat(n*4+2), gPat(n*4+3)]
    NEXT n
END PROC
