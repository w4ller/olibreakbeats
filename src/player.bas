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

' SET_TEMPO  [bpm]
' Imposta il tempo di riproduzione in BPM assoluti.
' Base: delay=24 corrisponde a ~150 BPM.
' Formula: newDelay = 24 * 150 / bpm = 3600 / bpm
' Range utile: 50-300 BPM
' =============================================================================
PROCEDURE set_tempo[bpm AS INTEGER]
    DIM newDelay AS INTEGER

    ' delay=24 -> 150 BPM  => newDelay = 3600 / bpm
    newDelay = 3600 / bpm

    ' Limita il range per sicurezza (300 BPM min delay=12, 50 BPM max delay=72)
    IF newDelay < 12 THEN newDelay = 12  :' max ~300 BPM
    IF newDelay > 72 THEN newDelay = 72  :' min ~50 BPM

    gPlaybackDelay(0) = newDelay

    ' gTempoFactor: normalizzato su 150 BPM base (128 = 150 BPM)
    ' Usato da play_note_ex per compensare il pitch al variare del tempo
    gTempoFactor = (bpm * 128) / 150
END PROC


' =============================================================================
' PLAY_CHUNK_ASM_REV
' Come play_chunk_asm ma legge il chunk al contrario.
' gWaveBase deve puntare all ULTIMO byte del chunk (non al primo).
' Step e' POSITIVO (non negato): la routine lo sottrae tramite NEGA+LEAU.
'
' Tecnica decremento:
'   ABX usa ACCB come UNSIGNED -> non puo fare decremento.
'   LEAU A,U usa A come SIGNED 8-bit -> NEGA + LEAU A,U decrementa.
'   Es: step=1.0 -> A=1 -> NEGA -> A=$FF (-1) -> LEAU A,U -> U-=1. Corretto.
'
' Registro U usato come puntatore (X resta libero per ugBasic).
' Overhead vs play_chunk_asm: +2 cicli/sample (NEGA) = ~5% su 8kHz.
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
        wId = RND(5)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

    sz            = 9600 / chunkDiv
    gChunkSize(0) = sz / 256
    gChunkSize(1) = sz AND $FF
    addr          = waveAddress(wId) + (sz * actualIdx)
    gWaveBase(0)  = addr / 256
    gWaveBase(1)  = addr AND $FF
    gWavBank(0)   = wavBank(wId)
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' PLAY_NOTE_REV  [chunkIdx, chunkDiv, stepHi, stepLo, waveId]
' Come play_note ma suona il chunk al contrario tramite play_chunk_asm_rev.
' Step passato POSITIVO (non negato): e play_chunk_asm_rev che lo inverte.
' gWaveBase punta all ultimo byte del chunk.
' =============================================================================
PROCEDURE play_note_rev[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE]
    DIM actualIdx AS BYTE
    DIM addr      AS ADDRESS
    DIM sz        AS INTEGER
    DIM wId       AS BYTE

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

    sz = 9600 / chunkDiv

    ' Punta all ultimo byte del chunk
    addr         = waveAddress(wId) + (sz * actualIdx) + sz - 1
    gWaveBase(0) = addr / 256
    gWaveBase(1) = addr AND $FF
    gWavBank(0)  = wavBank(wId)

    gChunkSize(0) = sz / 256
    gChunkSize(1) = sz AND $FF

    ' Step positivo: e play_chunk_asm_rev che lo usa negato via NEGA+LEAU
    gStepHi(0) = stepHi
    gStepLo(0) = stepLo
    CALL play_chunk_asm_rev
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
' stutterMode: vedi play_note_stutter / globals.bas
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
    DIM adjustedHi  AS BYTE
    DIM adjustedLo  AS BYTE
    DIM tempProduct AS INTEGER


 ' --- Compensa lo step per il tempo corrente ---
    ' step_compensato = step * (128 / gTempoFactor)
    ' Per mantenere il pitch quando il tempo cambia
    tempProduct = (stepHi * 256 + stepLo) * 128 / gTempoFactor
    adjustedHi = tempProduct / 256
    adjustedLo = tempProduct AND $FF


    IF reverseMode = $FF THEN
        doRev = RND(2)  :' 0=forward, 1=reverse
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
            play_note[chunkIdx, chunkDiv, adjustedHi, adjustedLo, waveId]
        ELSE
            play_note_rev[chunkIdx, chunkDiv, adjustedHi, adjustedLo, waveId]
        ENDIF
    ELSE
        ' ... usa adjustedHi/Lo nel loop stutter ...
        curHi = adjustedHi
        curLo = adjustedLo
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
                play_note[baseIdx, newDiv, curHi, curLo, waveId]
            ELSE
                play_note_rev[baseIdx, newDiv, curHi, curLo, waveId]
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
