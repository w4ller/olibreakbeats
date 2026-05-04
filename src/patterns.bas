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
' PLAY_PATTERN[pat(), nNotes]
' Suona nNotes note dall'array pat.
' Formato array: [idx, div, stepHi, stepLo] x nNotes
' =============================================================================
PROCEDURE play_pattern[pat() AS BYTE, nNotes AS BYTE]
    DIM n AS BYTE
    FOR n = 0 TO nNotes - 1
        play_note[pat(n*4), pat(n*4+1), pat(n*4+2), pat(n*4+3)]
    NEXT n
END PROC
