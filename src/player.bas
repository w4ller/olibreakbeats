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
' Loop stutter proporzionale con pitch delta opzionale per ripetizione.
'
' stutterMode 0..11: vedi tabella in init_stutter (globals.bas)
' stutterMode $FF  : RND tra sm 0..11 a runtime
'
' Algoritmo:
'   1. Risolve sm e reps dalla lookup table stutterReps
'   2. Calcola newDiv = chunkDiv * reps (chunk proporzionalmente piu piccolo)
'   3. Risolve baseIdx (scala chunkIdx, oppure RND risolto una volta sola)
'   4. Loop reps volte: suona baseIdx, poi moltiplica step per delta 8.8
'      Per sm 0..3 delta=$0100 (x1.0) -> pitch invariato, zero overhead
' Richiede init_stutter chiamato una volta a startup.
' =============================================================================
PROCEDURE play_note_stutter[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE]
    DIM sm      AS BYTE
    DIM r       AS BYTE
    DIM newDiv  AS BYTE
    DIM baseIdx AS BYTE
    DIM reps    AS BYTE
    DIM curHi   AS BYTE
    DIM curLo   AS BYTE
    DIM product AS INTEGER

    IF stutterMode = $FF THEN
        sm = RND(12)  :' 0..11
    ELSE
        sm = stutterMode
    ENDIF

    reps = stutterReps(sm)  :' O(1) lookup

    IF reps = 1 THEN
        play_note[chunkIdx, chunkDiv, stepHi, stepLo, waveId]
    ELSE
        newDiv = chunkDiv * reps

        IF chunkIdx = $FF THEN
            baseIdx = RND(chunkDiv) * reps  :' RND risolto una volta sola
        ELSE
            baseIdx = chunkIdx * reps
        ENDIF

        curHi = stepHi
        curLo = stepLo

        FOR r = 0 TO reps - 1
            play_note[baseIdx, newDiv, curHi, curLo, waveId]
            ' moltiplica step 8.8 per delta 8.8: (cur * delta) >> 8
            ' per sm 0..3 delta=$0100 -> product/256 = cur, pitch invariato
            product = (curHi * 256 + curLo) * (stutterDeltaHi(sm) * 256 + stutterDeltaLo(sm))
            product = product / 256
            curHi = product / 256
            curLo = product AND $FF
        NEXT r
    ENDIF

END PROC
