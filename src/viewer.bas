' =============================================================================
' viewer.bas - Pattern viewer v0.1 MINIMAL
' Solo CLS + stampa stringa fissa. Da espandere progressivamente.
' =============================================================================

DIM gModeViewer AS BYTE : GLOBAL gModeViewer

PROCEDURE viewer_entry
    ON CPU6809 BEGIN ASM

; Indirizzi ROM MO6/PC128
VW_PUTCH   EQU $E803
VW_CLS     EQU $E806

vw_start:
        JSR     VW_CLS          ; pulisce schermo

        ; stampa "VIEWER OK" carattere per carattere
        LDA     #'V'
        JSR     VW_PUTCH
        LDA     #'I'
        JSR     VW_PUTCH
        LDA     #'E'
        JSR     VW_PUTCH
        LDA     #'W'
        JSR     VW_PUTCH
        LDA     #'E'
        JSR     VW_PUTCH
        LDA     #'R'
        JSR     VW_PUTCH
        LDA     #' '
        JSR     VW_PUTCH
        LDA     #'O'
        JSR     VW_PUTCH
        LDA     #'K'
        JSR     VW_PUTCH

        ; aspetta un tasto qualsiasi (SWI $0C, bloccante)
vw_wait:
        SWI
        FCB     $0C
        BCC     vw_wait

        RTS                     ; ritorna al BASIC

    END ASM ON CPU6809
END PROC
