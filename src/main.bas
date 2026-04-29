' =============================================================================
' olibreakbeats — main.bas   v0.3  (Passo 3)
' Thomson MO6 / UGBasic / Motorola 6809
'
' Legge i pattern da assets/patterns.bin invece di hardcodarli.
'
' Formato patterns.bin:
'   byte 0     : N = numero di pattern
'   byte 1..2  : WORD big-endian offset assoluto pattern 1
'   byte 3..4  : WORD big-endian offset assoluto pattern 2
'   ...
'   poi dati: ogni nota = 4 byte  DIV IDX STEP_HI STEP_LO
'   nessun terminatore: lunghezza = (offset_next - offset_cur) / 4
'
' Tasti 1..9 (o quanti pattern ci sono) per switchare pattern al volo.
' Qualsiasi altro tasto per fermarsi.
' =============================================================================

' --- Sample (raw PCM 8kHz 8-bit unsigned mono) ---
GLOBAL wave
wave = LOAD("assets/amen150.bin")

' --- Pattern file ---
GLOBAL patFile
patFile = LOAD("assets/patterns.bin")

' --- Numero di pattern letto dall'header ---
DIM nPatterns  AS BYTE    : GLOBAL nPatterns

' --- Pattern corrente (1-based) ---
DIM curPattern AS INTEGER : GLOBAL curPattern

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
' Suona un chunk del sample con step (pitch) specificato.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    gChunkSize = SIZE(wave) / chunkDiv
    gWaveBase  = VARPTR(wave) + (gChunkSize * chunkIdx)
    gStepHi    = stepHi
    gStepLo    = stepLo
    CALL play_chunk_asm
END PROC

' =============================================================================
' PLAY_PATTERN
' Legge e suona tutte le note del pattern patIdx (1-based) da patFile.
'
' Header:  byte 0 = N,  byte 1..2 = offset pat1,  byte 3..4 = offset pat2 ...
' Offset assoluti dall'inizio del file, big-endian WORD.
' Numero note = (offset_next - offset_cur) / 4
' Ultimo pattern: (SIZE(patFile) - offset_cur) / 4
' =============================================================================
PROCEDURE play_pattern[patIdx AS BYTE]
    DIM base     AS ADDRESS
    DIM offCur   AS INTEGER
    DIM offNext  AS INTEGER
    DIM noteCount AS INTEGER
    DIM noteAddr AS ADDRESS
    DIM n        AS INTEGER
    DIM bDiv     AS BYTE
    DIM bIdx     AS BYTE
    DIM bStepHi  AS BYTE
    DIM bStepLo  AS BYTE

    base = VARPTR(patFile)

    ' Leggi offset corrente: header[patIdx] = byte a posizione (patIdx-1)*2 + 1
    offCur = PEEK(base + 1 + (patIdx - 1) * 2) * 256 + PEEK(base + 2 + (patIdx - 1) * 2)

    ' Leggi offset prossimo (o fine file se ultimo pattern)
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
' Main
' =============================================================================
PRINT "olibreakbeats v0.3"
CALL init_dac

' Leggi numero di pattern dall'header
nPatterns  = PEEK(VARPTR(patFile))
curPattern = 1

PRINT "Pattern disponibili: "; nPatterns
PRINT "Premi 1-"; nPatterns; " per scegliere. Altro tasto = stop."

DO
    ' Controlla tasto prima di ogni bar
    DIM k AS BYTE
    k = INKEY()
    IF k >= 49 AND k <= 57 THEN        ' tasti ASCII '1'..'9'
        DIM req AS BYTE
        req = k - 48
        IF req >= 1 AND req <= nPatterns THEN
            curPattern = req
            PRINT "Pattern: "; curPattern
        END IF
    ELSE IF k > 0 THEN
        PRINT "Stop."
        END
    END IF

    play_pattern[curPattern]
LOOP
