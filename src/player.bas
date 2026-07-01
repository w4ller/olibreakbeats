' =============================================================================
' PLAY_CHUNK_ASM
' Outputs gChunkSize samples from gWaveBase at 8.8 fixed-point step.
' Legge dalla fine del BANK corrente (settato da gWavBank).
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

        LDB   _gPlaybackDelay 
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
' SET_TEMPO  [bpm]
' Imposta il tempo di riproduzione in BPM assoluti.
' Base: delay=24 corrisponde a ~150 BPM.
' Formula: newDelay = 24 * 150 / bpm = 3600 / bpm
' Range utile: 50-300 BPM
' =============================================================================
PROCEDURE set_tempo[targetBPM AS BYTE]
    DIM newDelay AS INTEGER
    DIM baseBPM AS BYTE

    baseBPM = 150  :' Il tempo base con delay=24

    newDelay = (24 * baseBPM) / targetBPM  :' = 3600 / targetBPM

    IF newDelay < 12 THEN newDelay = 12  :' max 300 BPM
    IF newDelay > 48 THEN newDelay = 48  :' min 75 BPM

    gPlaybackDelay(0) = newDelay

    gTempoFactor = (targetBPM * 128) / baseBPM
END PROC


' =============================================================================
' PLAY_CHUNK_ASM_REV
' Come play_chunk_asm ma legge il chunk al contrario.
' gWaveBase deve puntare all ULTIMO byte del chunk (non al primo).
' Step e POSITIVO (non negato): la routine lo sottrae tramite NEGA+LEAU.
' =============================================================================
PROC play_chunk_asm_rev
    ON CPU6809 BEGIN ASM
        LDU   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc

        LDA   _gWavBank
        STA   $A7E5

PCR_LOOP:
        LDA   0,U
        STA   $A7CD

        LDB   _gPlaybackDelay
PCR_DLY:
        DECB
        BNE   PCR_DLY

        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDA   _gStepHi
        ADCA  #0
        NEGA
        LEAU  A,U

        LEAY  -1,Y
        BNE   PCR_LOOP

        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC


' =============================================================================
' PLAY_NOTE  [chunkIdx, chunkDiv, stepHi, stepLo, waveId]
' Suona un chunk della wave.
'
' Per div <= 16: normalizzato a sotto-blocchi da 600 campioni (1/16).
'   subCount = 16/div, gChunkSize = 600, overhead ugBasic costante.
'
' Per div > 16 (stutter estremo, es. div=32): chunk reale < 600 campioni.
'   subCount = 1, gChunkSize = 9600/div (dimensione reale).
'   Evita lettura oltre i limiti del chunk -> no rumore.
' =============================================================================
PROCEDURE play_note[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE]
    DIM actualIdx  AS BYTE
    DIM addr       AS ADDRESS
    DIM wId        AS BYTE
    DIM subCount   AS BYTE
    DIM s          AS BYTE
    DIM subBase    AS ADDRESS
    DIM chunkSize  AS INTEGER  :' dimensione reale del chunk in campioni

    IF waveId = $FF THEN
        wId = RND(5)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

    IF chunkDiv <= 16 THEN
        subCount  = 16 / chunkDiv   :' es. div=4 -> 4 sotto-chunk da 600
        chunkSize = 600
    ELSE
        subCount  = 1               :' div>16: 1 sola chiamata ASM
        chunkSize = 9600 / chunkDiv :' es. div=32 -> 300 campioni reali
    ENDIF

    subBase = waveAddress(wId) + (chunkSize * actualIdx)

    gChunkSize(0) = chunkSize / 256
    gChunkSize(1) = chunkSize AND $FF
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    gWavBank(0)   = wavBank(wId)

    FOR s = 0 TO subCount - 1
        addr         = subBase + (chunkSize * s)
        gWaveBase(0) = addr / 256
        gWaveBase(1) = addr AND $FF
        CALL play_chunk_asm
    NEXT s
END PROC


' =============================================================================
' PLAY_NOTE_REV  [chunkIdx, chunkDiv, stepHi, stepLo, waveId]
' Come play_note ma suona i sotto-chunk al contrario tramite play_chunk_asm_rev.
' Stessa logica di cap per div > 16.
' =============================================================================
PROCEDURE play_note_rev[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE]
    DIM actualIdx  AS BYTE
    DIM addr       AS ADDRESS
    DIM wId        AS BYTE
    DIM subCount   AS BYTE
    DIM s          AS BYTE
    DIM subBase    AS ADDRESS
    DIM chunkSize  AS INTEGER

    IF waveId = $FF THEN
        wId = RND(5)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

    IF chunkDiv <= 16 THEN
        subCount  = 16 / chunkDiv
        chunkSize = 600
    ELSE
        subCount  = 1
        chunkSize = 9600 / chunkDiv
    ENDIF

    subBase = waveAddress(wId) + (chunkSize * actualIdx)

    gChunkSize(0) = chunkSize / 256
    gChunkSize(1) = chunkSize AND $FF
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    gWavBank(0)   = wavBank(wId)

    ' Sotto-chunk in ordine inverso, ciascuno letto al contrario
    s = subCount
    DO
        s = s - 1
        addr         = subBase + (chunkSize * s) + (chunkSize - 1)
        gWaveBase(0) = addr / 256
        gWaveBase(1) = addr AND $FF
        CALL play_chunk_asm_rev
    LOOP WHILE s > 0
END PROC


' =============================================================================
' PLAY_NOTE_EX  [chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode, reverseMode]
' Wrapper unico che combina reverse e stutter.
'
' reverseMode:
'   0   = forward (default, backward compatible)
'   1   = reverse
'   255 = RND forward o reverse a runtime
'
' stutterMode: vedi globals.bas
' Con stutter reps>1, newDiv = chunkDiv*reps puo superare 16.
' play_note/play_note_rev gestiscono entrambi i casi correttamente.
' =============================================================================
PROCEDURE play_note_ex[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE, reverseMode AS BYTE]
    DIM doRev       AS BYTE
    DIM sm          AS BYTE
    DIM r           AS BYTE
    DIM newDiv      AS BYTE
    DIM baseIdx     AS BYTE
    DIM reps        AS BYTE
    DIM curHi       AS BYTE
    DIM curLo       AS BYTE
    DIM product     AS INTEGER
    DIM dHi         AS BYTE
    DIM dLo         AS BYTE

    IF reverseMode = $FF THEN
        doRev = RND(2)
    ELSE
        doRev = reverseMode
    ENDIF

    IF stutterMode = $FF THEN
        sm = RND(12)
    ELSE IF stutterMode = $FE THEN
        sm = 4 + RND(4)
    ELSE IF stutterMode = $FD THEN
        sm = 8 + RND(4)
    ELSE IF stutterMode = $FC THEN
        sm = 4 + RND(8)
    ELSE IF stutterMode = $FB THEN
        sm = RND(4)
    ELSE
        sm = stutterMode
    ENDIF

    reps = stutterReps(sm)

    IF reps = 1 THEN
        IF doRev = 0 THEN
            play_note[chunkIdx, chunkDiv, stepHi, stepLo, waveId]
        ELSE
            play_note_rev[chunkIdx, chunkDiv, stepHi, stepLo, waveId]
        ENDIF
    ELSE
        newDiv = chunkDiv * reps

        IF chunkIdx = $FF THEN
            baseIdx = RND(chunkDiv) * reps
        ELSE
            baseIdx = chunkIdx * reps
        ENDIF

        curHi = stepHi
        curLo = stepLo
        dHi   = stutterDeltaHi(sm)
        dLo   = stutterDeltaLo(sm)

        FOR r = 0 TO reps - 1
            IF doRev = 0 THEN
                play_note[baseIdx + r, newDiv, curHi, curLo, waveId]
            ELSE
                play_note_rev[baseIdx + r, newDiv, curHi, curLo, waveId]
            ENDIF
            product = (curHi * dHi * 256) + (curHi * dLo) + (curLo * dHi)
            curHi = product / 256
            curLo = product AND $FF
        NEXT r
    ENDIF

END PROC


' =============================================================================
' PLAY_NOTE_STUTTER  [chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode]
' Backward compatible: chiama play_note_ex con reverseMode=0.
' =============================================================================
PROCEDURE play_note_stutter[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE]
    play_note_ex[chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode, 0]
END PROC
