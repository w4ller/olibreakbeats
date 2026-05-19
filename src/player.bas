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
' PLAY_NOTE  [chunkIdx, chunkDiv, stepHi, stepLo, waveId]
' chunkIdx = $FF -> random chunk in 0..chunkDiv-1
' chunkDiv = number of equal slices the wave is divided into
' stepHi/Lo = 8.8 fixed-point pitch multiplier
' waveId   = 0..4 selects wave; $FF = random among 5 waves
' =============================================================================
PROCEDURE play_note[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE]
    DIM actualIdx AS BYTE
    DIM addr      AS ADDRESS
    DIM sz        AS INTEGER
    DIM wId       AS BYTE

    IF waveId = $FF THEN
        wId = RND(5)    :' random wave 0..4
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)   :' random slice 0..chunkDiv-1
    ELSE
        actualIdx = chunkIdx
    ENDIF

    sz            = 9600 / chunkDiv
    gChunkSize(0) = sz / 256
    gChunkSize(1) = sz AND $FF
    addr          = waveAddress(wId) + (sz * actualIdx) :' O(1) lookup, no IF chain
    gWaveBase(0)  = addr / 256
    gWaveBase(1)  = addr AND $FF
    gWavBank(0)   = wavBank(wId)
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' PLAY_NOTE_STUTTER  [chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode]
' Ripete play_note N volte sullo stesso chunk per ottenere l effetto stutter.
'
' stutterMode:
'   $00 = 1x  (nessuno stutter, comportamento normale)
'   $01 = 2x  (ripeti 2 volte)
'   $02 = 4x  (ripeti 4 volte)
'   $03 = 8x  (ripeti 8 volte)
'   $FF = RND: sceglie casualmente tra 1x, 2x, 4x a runtime
'
' Nota: la durata totale dello step e' moltiplicata per reps.
' Per mantenere il ritmo usare div proporzionalmente piu alto.
' =============================================================================
PROCEDURE play_note_stutter[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE]
    DIM reps AS BYTE
    DIM sm   AS BYTE
    DIM r    AS BYTE

    IF stutterMode = $FF THEN
        sm = RND(3)   :' 0=1x, 1=2x, 2=4x (random tra i tre modi base)
    ELSE
        sm = stutterMode
    ENDIF

    IF sm = 0 THEN
        reps = 1
    ELSE IF sm = 1 THEN
        reps = 2
    ELSE IF sm = 2 THEN
        reps = 4
    ELSE
        reps = 8
    ENDIF

    FOR r = 1 TO reps
        play_note[chunkIdx, chunkDiv, stepHi, stepLo, waveId]
    NEXT r
END PROC
