' =============================================================================
' olibreakbeats — main.bas   v0.5
' Thomson MO6 / UGBasic / Motorola 6809
'
' Legge i pattern da assets/patterns.bin.
' Il sample amen150.bin e' caricato BANKED (fuori dalla RAM principale).
' La copia chunk-by-chunk e' gestita da chunkCopy.bas (tecnica olitracker_2v).
'
' Formato patterns.bin:
'   byte 0     : N = numero di pattern
'   byte 1..2  : WORD big-endian offset assoluto pattern 1
'   byte 3..4  : WORD big-endian offset assoluto pattern 2
'   ...
'   poi dati: ogni nota = 4 byte  DIV IDX STEP_HI STEP_LO
'   nessun terminatore: lunghezza = (offset_next - offset_cur) / 4
'
' Input tastiera via SWI $0C (KBSTAT, non bloccante).
' Codici tasti MO6 misurati su dcmoto:
'   1=$0A  2=$12  3=$1A  4=$22  5=$2A  6=$32
'   7=$33  8=$2B  9=$23  0=$1B
' =============================================================================

' --- Sample nel bank espanso ---
GLOBAL wave
wave = LOAD("assets/amen150.bin") BANKED

' --- Pattern file (piccolo, rimane in RAM principale) ---
GLOBAL patFile
patFile = LOAD("assets/patterns.bin")

' --- Include chunkCopy e buffer ---
INCLUDE "chunkCopy.bas"

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
' Configura PIA port B bits 0-5 come uscite per il DAC 6-bit.
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
' Legge un tasto in modo non bloccante via SWI $0C (KBSTAT).
' Risultato in gKeyPressed: 0 = nessun tasto.
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
' Emette gChunkSize campioni da gWaveBase (chunkBuf) al DAC.
' Step 8.8 fixed-point per pitch invariant-duration.
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
' 1. Copia il chunk richiesto dal bank al chunkBuf (RAM principale).
' 2. Suona il chunkBuf via play_chunk_asm.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM cs      AS INTEGER
    DIM srcAddr AS ADDRESS
    cs      = SIZE(wave) / chunkDiv
    srcAddr = VARPTR(wave) + (cs * chunkIdx)
    ' Copia chunk bank -> RAM principale
    SYS chunkCopyAddr WITH REG(A)=BANK(wave), REG(B)=defBank, REG(X)=srcAddr, REG(Y)=VARPTR(chunkBuf), REG(U)=cs ON CPU6809
    ' Player suona dal buffer locale
    gChunkSize = cs
    gWaveBase  = VARPTR(chunkBuf)
    gStepHi    = stepHi
    gStepLo    = stepLo
    CALL play_chunk_asm
END PROC

' =============================================================================
' PLAY_PATTERN
' Legge e suona tutte le note del pattern patIdx (1-based) da patFile.
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

    base = VARPTR(patFile)

    offCur = PEEK(base + 1 + (patIdx - 1) * 2) * 256 + PEEK(base + 2 + (patIdx - 1) * 2)

    IF patIdx >= nPatterns THEN
        offNext = SIZE(patFile)
    ELSE
        offNext = PEEK(base + 1 + patIdx * 2) * 256 + PEEK(base + 2 + patIdx * 2)
    END IF

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
' Mappa i codici tasto MO6 al pattern desiderato.
' Codici misurati su dcmoto:
'   1=$0A 2=$12 3=$1A 4=$22 5=$2A 6=$32 7=$33 8=$2B 9=$23
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
            END IF
    END SELECT
    IF req >= 1 AND req <= nPatterns THEN
        curPattern = req
        PRINT "Pattern: "; curPattern
    END IF
END PROC

' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.5"
CALL init_dac

nPatterns  = PEEK(VARPTR(patFile))
curPattern = 1

PRINT "Pattern disponibili: "; nPatterns
PRINT "1-9 = pattern  altro tasto = stop"

DO
    CALL check_key
    handle_key[gKeyPressed]
    play_pattern[curPattern]
LOOP
