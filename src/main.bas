' =============================================================================
' olibreakbeats - main.bas   v0.9
' Thomson MO6 / UGBasic / Motorola 6809
'
' v0.9: buffer ridotto a 256 byte in RAM residente.
'   play_note copia e suona il chunk in blocchi da 256 byte max.
'   Sintassi BANK READ: BANK READ VARBANK(src) FROM ptr TO VARPTR(dst) SIZE n
'
' Formato patterns.bin:
'   byte 0     : N = numero di pattern
'   byte 1..2  : WORD big-endian offset pattern 1
'   byte 3..4  : WORD big-endian offset pattern 2
'   poi dati   : ogni nota = 4 byte  DIV IDX STEP_HI STEP_LO
'
' Codici tasti MO6:
'   1=$0A  2=$12  3=$1A  4=$22  5=$2A  6=$32
'   7=$33  8=$2B  9=$23  0=$1B
' =============================================================================

CLS

' --- Asset BANKED ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- Buffer in RAM residente (sotto $6000) ---
INCLUDE "src/chunkCopy.bas"

' --- Globals ---
DIM nPatterns   AS BYTE    : GLOBAL nPatterns
DIM curPattern  AS BYTE    : GLOBAL curPattern
DIM gKeyPressed AS BYTE    : GLOBAL gKeyPressed

' --- Interfaccia ASM player ---
DIM gWaveBase  AS ADDRESS : GLOBAL gWaveBase
DIM gChunkSize AS INTEGER : GLOBAL gChunkSize
DIM gStepHi    AS BYTE    : GLOBAL gStepHi
DIM gStepLo    AS BYTE    : GLOBAL gStepLo
DIM gFracAcc   AS BYTE    : GLOBAL gFracAcc

' =============================================================================
' INIT_DAC
' =============================================================================
PROC init_dac
    ON CPU6809 BEGIN ASM
        LDA   $A7CF
        ANDA  #$FB
        STA   $A7CF
        LDB   #$3F
        STB   $A7CD
        ORA   #$04
        STA   $A7CF
    END ASM ON CPU6809
END PROC

' =============================================================================
' CHECK_KEY
' =============================================================================
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

' =============================================================================
' PLAY_CHUNK_ASM
' Suona gChunkSize campioni da gWaveBase con step gStepHi.gStepLo
' =============================================================================
PROC play_chunk_asm
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc

PCH_LOOP:
        LDA   0,X
        STA   $A7CD

        LDB   #24
PCH_DLY:
        DECB
        BNE   PCH_DLY

        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDB   _gStepHi
        ADCB  #0
        ABX

        LEAY  -1,Y
        BNE   PCH_LOOP
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_NOTE
' Copia il chunk dal bank a chunkBuf (256B per volta) e suona.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM totalSize AS INTEGER
    DIM srcOff    AS ADDRESS
    DIM remaining AS INTEGER
    DIM blockSize AS INTEGER

    totalSize = SIZE(wave) / chunkDiv
    srcOff    = VARBANKPTR(wave) + (totalSize * chunkIdx)
    remaining = totalSize
    gStepHi   = stepHi
    gStepLo   = stepLo

    WHILE remaining > 0
        IF remaining > 256 THEN
            blockSize = 256
        ELSE
            blockSize = remaining
        ENDIF
        BANK READ VARBANK(wave) FROM srcOff TO VARPTR(chunkBuf) SIZE blockSize
        gChunkSize = blockSize
        gWaveBase  = VARPTR(chunkBuf)
        CALL play_chunk_asm
        srcOff    = srcOff + blockSize
        remaining = remaining - blockSize
    WEND
END PROC

' =============================================================================
' PLAY_PATTERN
' Legge da patBuf (RAM residente, copiato all avvio).
' =============================================================================
PROCEDURE play_pattern[patIdx AS BYTE]
    DIM base      AS ADDRESS
    DIM offCur    AS INTEGER
    DIM offNext   AS INTEGER
    DIM noteCount AS INTEGER
    DIM noteAddr  AS ADDRESS
    DIM n         AS INTEGER
    DIM bDiv      AS BYTE
    DIM bIdx      AS BYTE
    DIM bStepHi   AS BYTE
    DIM bStepLo   AS BYTE

    base = VARPTR(patBuf)

    offCur  = PEEK(base + 1 + (patIdx - 1) * 2) * 256 + PEEK(base + 2 + (patIdx - 1) * 2)

    IF patIdx >= nPatterns THEN
        offNext = SIZE(patFile)
    ELSE
        offNext = PEEK(base + 1 + patIdx * 2) * 256 + PEEK(base + 2 + patIdx * 2)
    ENDIF

    noteCount = (offNext - offCur) / 4
    noteAddr  = base + offCur

    FOR n = 0 TO noteCount - 1
        bDiv    = PEEK(noteAddr + n * 4)
        bIdx    = PEEK(noteAddr + n * 4 + 1)
        bStepHi = PEEK(noteAddr + n * 4 + 2)
        bStepLo = PEEK(noteAddr + n * 4 + 3)
        play_note[bIdx, bDiv, bStepHi, bStepLo]
    NEXT n
END PROC

' =============================================================================
' HANDLE_KEY
' =============================================================================
PROCEDURE handle_key[k AS BYTE]
    DIM req AS BYTE
    req = 0
    SELECT CASE k
        CASE $0A : req = 1
        CASE $12 : req = 2
        CASE $1A : req = 3
        CASE $22 : req = 4
        CASE $2A : req = 5
        CASE $32 : req = 6
        CASE $33 : req = 7
        CASE $2B : req = 8
        CASE $23 : req = 9
        CASE ELSE
            IF k <> 0 THEN
                PRINT "Stop."
                END
            ENDIF
    ENDSELECT
    IF req >= 1 AND req <= nPatterns THEN
        curPattern = req
        PRINT "Pattern: "; curPattern
    ENDIF
END PROC

' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.9"
CALL init_dac

' Copia patterns.bin (128 byte max) dal bank a patBuf
BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(patBuf) SIZE 128

nPatterns  = PEEK(VARPTR(patBuf))
curPattern = 1

PRINT "patterns: "; nPatterns
PRINT "1-9 = pattern  altro = stop"

DO
    CALL check_key
    handle_key[gKeyPressed]
    play_pattern[curPattern]
LOOP
