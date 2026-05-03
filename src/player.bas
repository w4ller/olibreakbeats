' =============================================================================
' PLAY_CHUNK_ASM
' Outputs gChunkSize samples from gWaveBase at 8.8 fixed-point step.
' Timing loop: ~125us per sample = ~8kHz.
' Bank is restored to 7 after playback.
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
' PLAY_NOTE  [chunkIdx, chunkDiv, stepHi, stepLo]
' chunkIdx = $FF -> random chunk in 0..chunkDiv-1
' chunkDiv = number of equal slices the wave is divided into
' stepHi/Lo = 8.8 fixed-point pitch multiplier
' =============================================================================
PROCEDURE play_note[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE]
    DIM actualIdx AS BYTE
    DIM addr      AS ADDRESS
    DIM sz        AS INTEGER
    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)   :' random slice 0..chunkDiv-1
    ELSE
        actualIdx = chunkIdx
    ENDIF
    sz            = 9600 / chunkDiv
    gChunkSize(0) = sz / 256
    gChunkSize(1) = sz AND $FF
    addr          = VARBANKPTR(wave) + (sz * actualIdx)
    gWaveBase(0)  = addr / 256
    gWaveBase(1)  = addr AND $FF
    gWavBank(0)   = VARBANK(wave)
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    CALL play_chunk_asm
END PROC
