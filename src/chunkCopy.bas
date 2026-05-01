' =============================================================================
' chunkCopy.bas  -  buffer RAM residente per BANK READ
' v0.9: buffer ridotto a 256 byte per stare in RAM residente MO6
' =============================================================================

' Buffer wave: 256 byte massimo per blocco
DIM chunkBuf AS BYTE (256) FOR BANK READ : GLOBAL chunkBuf

' Buffer patterns.bin: 128 byte (il file e' piccolo)
DIM patBuf AS BYTE (128) FOR BANK READ : GLOBAL patBuf
