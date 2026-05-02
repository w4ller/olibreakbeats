' =============================================================================
' olibreakbeats — main.bas   v0.5  (Passo 5)
' Thomson MO6 / UGBasic / Motorola 6809
'
' PASSO 5: amen150.bin caricato in memoria BANKED.
' play_chunk_asm fa il bank switch internamente:
'   STA $A7E5  -> attiva banco WAV
'   ... loop DAC ...
'   LDA #7 / STA $A7E5  -> ripristina banco normale
'
' Il resto (delay B=24, step 8.8, gChunkSize/gWaveBase) e' identico
' alla v0.2 che funzionava.
'
' Step 8.8 fixed-point:
'   $0100 = 1.0x  pitch originale
'   $0200 = 2.0x  ottava sopra
'   $0180 = 1.5x  quinta sopra
'   $0080 = 0.5x  ottava sotto
'   $00C0 = 0.75x quarta sotto
' =============================================================================


' --- Sample BANKED (raw PCM 8kHz 8-bit unsigned mono) ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED


' --- Interfaccia ASM player ---
DIM gWaveBase  AS ADDRESS : GLOBAL gWaveBase   ' puntatore al chunk corrente
DIM gChunkSize AS INTEGER : GLOBAL gChunkSize  ' campioni da emettere
DIM gStepHi    AS BYTE    : GLOBAL gStepHi     ' step parte intera  (8.8)
DIM gStepLo    AS BYTE    : GLOBAL gStepLo     ' step parte frazionaria
DIM gFracAcc   AS BYTE    : GLOBAL gFracAcc    ' accumulatore frazionario
DIM gWavBank   AS BYTE    : GLOBAL gWavBank    ' numero banco del WAV


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
' Identico alla v0.2 tranne per il bank switch attorno al loop:
'   - attiva gWavBank prima del loop
'   - ripristina banco 7 dopo il loop
' gWaveBase punta direttamente al dato nel map 6809 dopo il bank switch.
' =============================================================================
PROC play_chunk_asm
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc

        ; --- attiva banco WAV ---
        LDA   _gWavBank
        STA   $A7E5

PCH_LOOP:
        LDA   0,X
        STA   $A7CD

        ; --- delay calibrato (B=24, identico v0.2) ---
        LDB   #24
PCH_DLY:
        DECB
        BNE   PCH_DLY

        ; --- avanzamento fixed-point 8.8 ---
        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDB   _gStepHi
        ADCB  #0
        ABX

        LEAY  -1,Y
        BNE   PCH_LOOP

        ; --- ripristina banco normale (7) ---
        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC


' =============================================================================
' PLAY_NOTE
' Come v0.2 ma usa VARBANKPTR/VARBANK invece di VARPTR/SIZE.
' La dimensione del WAV e' fissa: 9600 byte (1 secondo a 9600 Hz).
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM wavSize AS INTEGER
    wavSize    = 9600
    gChunkSize = wavSize / chunkDiv
    gWaveBase  = VARBANKPTR(wave) + (gChunkSize * chunkIdx)
    gWavBank   = VARBANK(wave)
    gStepHi    = stepHi
    gStepLo    = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.5 - Passo 5 (wave BANKED)"
CALL init_dac


DO
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
