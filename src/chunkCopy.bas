' =============================================================================
' chunkCopy.bas  -  DEPRECATO in v0.8
' Sostituito da BANK READ nativo ugBASIC:
'   BANK READ VARBANK(src) FROM VARBANKPTR(src) TO VARPTR(dst) SIZE n
' File mantenuto per compatibilita storica.
' =============================================================================

' Buffer di lavoro: chunk max = 9600/4 = 2400 byte, in RAM residente
DIM chunkBuf AS BYTE (2400) FOR BANK READ : GLOBAL chunkBuf

' Buffer per patterns.bin, in RAM residente
DIM patBuf AS BYTE (512) FOR BANK READ : GLOBAL patBuf
