' =============================================================================
' olibreakbeats — main.bas   v0.2  (Passo 2)
' Thomson MO6 / UGBasic / Motorola 6809
'
' ASM core player con step variabile per slot (pitch senza cambiare ritmo).
' Delay calibrato empiricamente su dcmoto: B=72 → ~8kHz output rate.
'
' Nota clock MO6: la CPU 6809 nel Thomson MO6 gira a ~3.58 MHz nominali.
' Il valore B=72 e' il riferimento calibrato empiricamente — non modificare
' senza riverificare il pitch su dcmoto.
'
' Step 8.8 fixed-point: parte alta = intera, parte bassa = frazionaria.
'   $0100 = 1.0x  pitch originale
'   $0200 = 2.0x  ottava sopra
'   $0180 = 1.5x  quinta sopra
'   $0080 = 0.5x  ottava sotto
'   $00C0 = 0.75x quarta sotto
' =============================================================================


' --- Sample (raw PCM 8kHz 8-bit unsigned mono) ---
GLOBAL wave
wave = LOAD("assets/amen150.bin")


' --- Interfaccia ASM player ---
' pointer to start of current chunk
DIM gWaveBase  AS ADDRESS : GLOBAL gWaveBase
' number of output samples (fixed duration)
DIM gChunkSize AS INTEGER  : GLOBAL gChunkSize
' step integer part  (8.8 fixed-pt)
DIM gStepHi    AS BYTE : GLOBAL gStepHi
' step fractional part
DIM gStepLo    AS BYTE : GLOBAL gStepLo
' fractional accumulator (reset each chunk)
DIM gFracAcc   AS BYTE : GLOBAL gFracAcc


' =============================================================================
' INIT_DAC
' Configura PIA port B bits 0-5 come uscite per il DAC a 6 bit.
' Da chiamare una sola volta all'avvio.
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
' Emette esattamente gChunkSize campioni da gWaveBase al DAC.
'
' Durata   = gChunkSize x T_campione = COSTANTE (Y e' il contatore fisso).
' Pitch    = determinato da gStepHi.gStepLo (8.8 fixed-point).
'
' Aumentare B  -> sample rate piu' bassa -> tutto piu' lento E piu' grave.
' Cambiare step -> solo pitch, durata slot invariata.
'
' Delay calibrato empiricamente su dcmoto: B=72 -> ~8kHz.
' =============================================================================
PROC play_chunk_asm
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc


PCH_LOOP:
        LDA   0,X
        STA   $A7CD


        ; --- delay calibrato (B=24) ---
        LDB   #24
PCH_DLY:
        DECB
        BNE   PCH_DLY


        ; --- avanzamento fixed-point 8.8 ---
        ; gFracAcc += gStepLo  carry -> gStepHi
        ; X += gStepHi + carry
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
' Seleziona un chunk e lo suona con lo step (pitch) specificato.
'
'   chunkIdx  : quale fetta suonare (0 ... chunkDiv-1)
'   chunkDiv  : in quante fette uguali dividere il sample (4, 8, 16)
'   stepHi    : parte intera dello step 8.8  (es. $01 = 1.0x)
'   stepLo    : parte frazionaria dello step (es. $00 = .0, $80 = .5)
'
' Esempi:
'   play_note[0, 4, $01, $00]  primo quarto, pitch originale
'   play_note[1, 4, $02, $00]  secondo quarto, ottava sopra
'   play_note[2, 8, $00, $80]  terzo ottavo, ottava sotto
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    gChunkSize = SIZE(wave) / chunkDiv
    gWaveBase  = VARPTR(wave) + (gChunkSize * chunkIdx)
    gStepHi    = stepHi
    gStepLo    = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.2 - Passo 2"
CALL init_dac


' --- Pattern breakbeat con pitch variabile ---
' Notazione: play_note[chunkIndex, nChunk, stepHi, stepLo]
'
' I chunk a step $0200 (ottava sopra) suonano piu' acuti ma
' occupano lo stesso slot temporale.
' I chunk a step $0080 (ottava sotto) suonano piu' gravi.
DO
    ' --- Bar 1: pattern base con variazioni di pitch ---
    play_note[0, 1, $01, $00]
    play_note[0, 1, $01, $00]


    play_note[1, 4, $01, $00]
    play_note[3, 4, $01, $00]
    play_note[0, 4, $01, $00]
    play_note[3, 4, $01, $00]


    play_note[3, 8, $01, $0f]
    play_note[3, 8, $01, $1f]
    play_note[3, 8, $01, $30]
    play_note[3, 8, $01, $35]


    play_note[7, 16, $01, $46]
    play_note[7, 16, $01, $56]
    play_note[7, 16, $01, $66]
    play_note[7, 16, $01, $70]
    play_note[7, 16, $01, $80]
    play_note[7, 16, $01, $90]
    play_note[7, 16, $01, $A0]
    play_note[7, 16, $01, $C0]


LOOP
