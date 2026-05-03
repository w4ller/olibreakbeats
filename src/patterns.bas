' =============================================================================
' READ_NOTE_ASM
' Reads 4 bytes from banked RAM at gPatPtr into gNoteDiv/Idx/Shi/Slo.
' Does NOT advance gPatPtr (caller does it).
' Bank is restored to 7 after the read.
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

PROC read_header


END PROC
