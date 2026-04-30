' =============================================================================
' chunkCopy.bas  -  copia bank->RAM via PROC ASM
' Thomson MO6 / pc128op / UGBasic
'
' Uso:
'   gCopySrcBank = VARBANK(wave)
'   gCopyDefBank = 7
'   gCopySrc     = VARBANKPTR(wave)  <-- indirizzo relativo al bank
'   gCopyDst     = VARPTR(chunkBuf)
'   gCopyLen     = chunkSize
'   CALL bank_copy
' =============================================================================

DIM gCopySrcBank AS BYTE    : GLOBAL gCopySrcBank
DIM gCopyDefBank AS BYTE    : GLOBAL gCopyDefBank
DIM gCopySrc     AS ADDRESS : GLOBAL gCopySrc
DIM gCopyDst     AS ADDRESS : GLOBAL gCopyDst
DIM gCopyLen     AS INTEGER : GLOBAL gCopyLen

PROC bank_copy
    ON CPU6809 BEGIN ASM
        LDX   _gCopySrc        :' parametri prima del bank swap
        LDY   _gCopyDst
        LDD   _gCopyLen
        TFR   D,U
        LDA   _gCopySrcBank
        STA   $A7E5            :' seleziona bank sorgente
BC_LOOP:
        LDA   ,X+
        STA   ,Y+
        LEAU  -1,U
        CMPU  #0
        BNE   BC_LOOP
        LDA   _gCopyDefBank
        STA   $A7E5            :' ripristina bank default
    END ASM ON CPU6809
END PROC

' Buffer di lavoro: chunk max = 9600/4 = 2400 byte
DIM chunkBuf AS BYTE (2400) : GLOBAL chunkBuf
DIM defBank  AS BYTE        : GLOBAL defBank
defBank = 7

PRINT "chunkCopy ok"
