' =============================================================================
' chunkCopy.bas  -  buffer RAM residente per BANK READ
' v1.0: lettura lazy patterns.bin
'   patHeader : 19 byte  (1 byte N + max 9 pattern * 2 byte offset)
'   patNotes  : 128 byte (max 32 note * 4 byte = un 4/4 in trentaduesimi)
'   chunkBuf  : 256 byte (blocco wave)
'   Totale    : 403 byte in RAM residente
' =============================================================================

DIM chunkBuf  AS BYTE (256) FOR BANK READ : GLOBAL chunkBuf
DIM patHeader AS BYTE (19)  FOR BANK READ : GLOBAL patHeader
DIM patNotes  AS BYTE (128) FOR BANK READ : GLOBAL patNotes
