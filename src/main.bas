' =============================================================================
' olibreakbeats — main.bas   v0.6  (Passo 5+)
' Thomson MO6 / UGBasic / Motorola 6809
'
' v0.6: modalita generativa.
' Se chunkIdx = $FF, play_note sceglie un indice casuale tra 0..chunkDiv-1.
' Tutto il resto identico alla v0.5.
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
DIM gWaveBase  AS ADDRESS : GLOBAL gWaveBase
DIM gChunkSize AS INTEGER : GLOBAL gChunkSize
DIM gStepHi    AS BYTE    : GLOBAL gStepHi
DIM gStepLo    AS BYTE    : GLOBAL gStepLo
DIM gFracAcc   AS BYTE    : GLOBAL gFracAcc
DIM gWavBank   AS BYTE    : GLOBAL gWavBank


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

        LDA   _gWavBank
        STA   $A7E5

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

        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC


' =============================================================================
' PLAY_NOTE
' chunkIdx = $FF -> indice casuale tra 0..chunkDiv-1
' =============================================================================
PROCEDURE play_note[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE]
    DIM actualIdx AS BYTE
    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF
    gChunkSize = 9600 / chunkDiv
    gWaveBase  = VARBANKPTR(wave) + (gChunkSize * actualIdx)
    gWavBank   = VARBANK(wave)
    gStepHi    = stepHi
    gStepLo    = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.6 - generativo"
CALL init_dac


DO
    play_note[0, 1, $01, $00]
    play_note[0, 1, $01, $00]

    play_note[$FF, 4, $01, $00]
    play_note[$FF, 4, $01, $00]
    play_note[$FF, 4, $01, $00]
    play_note[$FF, 4, $01, $00]

    play_note[$FF, 8, $01, $0f]
    play_note[$FF, 8, $01, $1f]
    play_note[$FF, 8, $01, $30]
    play_note[$FF, 8, $01, $35]

    play_note[$FF, 16, $01, $46]
    play_note[$FF, 16, $01, $56]
    play_note[$FF, 16, $01, $66]
    play_note[$FF, 16, $01, $70]
    play_note[$FF, 16, $01, $80]
    play_note[$FF, 16, $01, $90]
    play_note[$FF, 16, $01, $A0]
    play_note[$FF, 16, $01, $C0]
LOOP
