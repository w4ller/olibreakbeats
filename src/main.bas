' =============================================================================
' olibreakbeats - audio-test branch
' Thomson MO6 / UGBasic / Motorola 6809
'
' Test minimalista: legge patterns.bin dall inizio alla fine
' e suona ogni nota in sequenza, in loop. Zero logica tasti.
' Buffer wave: 512 byte (max stabile in RAM residente).
' =============================================================================

CLS

GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- Buffer RAM residente ---
DIM chunkBuf AS BYTE (512) FOR BANK READ : GLOBAL chunkBuf
DIM patBuf   AS BYTE (300) FOR BANK READ : GLOBAL patBuf

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
' PLAY_CHUNK_ASM
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
' Suona un chunk del wave a blocchi da 512 byte.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM totalSize AS INTEGER
    DIM srcOff    AS ADDRESS
    DIM remaining AS INTEGER
    DIM blockSize AS INTEGER

    totalSize = 9600 / chunkDiv
    srcOff    = VARBANKPTR(wave) + (totalSize * chunkIdx)
    remaining = totalSize
    gStepHi   = stepHi
    gStepLo   = stepLo

    WHILE remaining > 0
        IF remaining > 512 THEN
            blockSize = 512
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
' Main: legge tutto patterns.bin e suona ogni nota in loop
' =============================================================================
PRINT "audio-test"
CALL init_dac

' Copia tutto patterns.bin in patBuf
BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(patBuf) SIZE 300

DIM nPat     AS BYTE    : nPat    = PEEK(VARPTR(patBuf))
DIM noteAddr AS ADDRESS : noteAddr = VARPTR(patBuf)
DIM fileSize AS INTEGER : fileSize = SIZE(patFile)

PRINT "nPat     : "; nPat
PRINT "fileSize : "; fileSize

' Calcola offset primo pattern (byte 1..2 big-endian)
DIM dataStart AS INTEGER
dataStart = PEEK(noteAddr + 1) * 256 + PEEK(noteAddr + 2)
PRINT "dataStart: "; dataStart

' Numero totale di note nel file
DIM totalNotes AS INTEGER
totalNotes = (fileSize - dataStart) / 4
PRINT "totNotes : "; totalNotes

DIM n       AS INTEGER
DIM bDiv    AS BYTE
DIM bIdx    AS BYTE
DIM bStepHi AS BYTE
DIM bStepLo AS BYTE
DIM addr    AS ADDRESS

DO
    FOR n = 0 TO totalNotes - 1
        addr    = noteAddr + dataStart + n * 4
        bDiv    = PEEK(addr)
        bIdx    = PEEK(addr + 1)
        bStepHi = PEEK(addr + 2)
        bStepLo = PEEK(addr + 3)
        play_note[bIdx, bDiv, bStepHi, bStepLo]
    NEXT n
LOOP
