' =============================================================================
' keytest.bas  —  mappa completa tasti MO6 via SWI $0C
' =============================================================================
DIM gKeyPressed AS BYTE : GLOBAL gKeyPressed

PROC check_key
    ON CPU6809 BEGIN ASM
        SWI
        FCB   $0C
        BCC   CK_NONE
        STB   _gKeyPressed
        BRA   CK_DONE
CK_NONE:
        CLR   _gKeyPressed
CK_DONE:
    END ASM ON CPU6809
END PROC

CLS
PRINT "Premi un tasto (ESC o BREAK per uscire)"
PRINT ""

DO
    CALL check_key
    IF gKeyPressed <> 0 THEN
        PRINT "DEC="; gKeyPressed; "  HEX=$"; HEX$(gKeyPressed); "  CHR="; CHR$(gKeyPressed)
        gKeyPressed = 0
    ENDIF
LOOP