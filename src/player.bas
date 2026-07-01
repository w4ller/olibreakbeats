' =============================================================================
' PLAY_CHUNK_ASM
' Outputs gChunkSize samples from gWaveBase at 8.8 fixed-point step.
' Legge dalla fine del BANK corrente (settato da gWavBank).
' Timing loop: overhead=47 cicli fissi + (5*B-1) cicli delay = 46+5*B totale.
' CPU ~996kHz -> B=24 produce ~6000 Hz = 9600 samples/bar @ 150 BPM.
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
' Imposta il tempo in BPM assoluti tramite formula.
' Formula: delay = 3600 / bpm  (calibrata su delay=24 @ 150 BPM = esatto)
' Per BPM presenti nella lookup table, preferire set_tempo_by_bpm.
' =============================================================================
PROCEDURE set_tempo[bpm AS INTEGER]
    DIM newDelay AS INTEGER

    newDelay = 3600 / bpm

    IF newDelay < 16 THEN newDelay = 16  :' max ~225 BPM
    IF newDelay > 32 THEN newDelay = 32  :' min ~112 BPM

    gPlaybackDelay(0) = newDelay
    gTempoFactor = (bpm * 128) / 150
END PROC


' =============================================================================
' SET_TEMPO_BY_INDEX  [idx]
' Imposta il tempo tramite indice diretto nella lookup (0=120BPM .. 16=200BPM).
' Operazione O(1): solo array lookup, nessun calcolo.
' =============================================================================
PROCEDURE set_tempo_by_index[idx AS BYTE]
    IF idx > 16 THEN idx = 16

    gTempoIndex       = idx
    gPlaybackDelay(0) = bpmDelayLookup(idx)
    gTempoFactor      = stepCompLookup(idx)
END PROC


' =============================================================================
' SET_TEMPO_BY_BPM  [targetBPM]
' Trova il BPM piu vicino nella lookup table e imposta delay + stepComp.
' Se il BPM e nella tabella, corrisponde a set_tempo_by_index (esatto).
' =============================================================================
PROCEDURE set_tempo_by_bpm[targetBPM AS BYTE]
    DIM i      AS BYTE
    DIM bestIdx AS BYTE
    DIM minDiff AS BYTE
    DIM diff    AS BYTE

    bestIdx = 6    :' default 150 BPM
    minDiff = 255

    FOR i = 0 TO 16
        IF bpmLookup(i) = targetBPM THEN
            bestIdx = i
            minDiff = 0
            i = 17  :' exit loop
        ELSE
            IF targetBPM > bpmLookup(i) THEN
                diff = targetBPM - bpmLookup(i)
            ELSE
                diff = bpmLookup(i) - targetBPM
            ENDIF
            IF diff < minDiff THEN
                minDiff = diff
                bestIdx = i
            ENDIF
        ENDIF
    NEXT i

    set_tempo_by_index[bestIdx]
END PROC


' =============================================================================
' TEMPO_UP
' Aumenta il tempo di uno step nella lookup (passo 5 BPM).
' =============================================================================
PROCEDURE tempo_up
    IF gTempoIndex < 16 THEN
        gTempoIndex       = gTempoIndex + 1
        gPlaybackDelay(0) = bpmDelayLookup(gTempoIndex)
        gTempoFactor      = stepCompLookup(gTempoIndex)
    ENDIF
END PROC


' =============================================================================
' TEMPO_DOWN
' Diminuisce il tempo di uno step nella lookup (passo 5 BPM).
' =============================================================================
PROCEDURE tempo_down
    IF gTempoIndex > 0 THEN
        gTempoIndex       = gTempoIndex - 1
        gPlaybackDelay(0) = bpmDelayLookup(gTempoIndex)
        gTempoFactor      = stepCompLookup(gTempoIndex)
    ENDIF
END PROC


' =============================================================================
' GET_CURRENT_BPM
' Ritorna il valore BPM nominale corrente dalla lookup.
' =============================================================================
FUNCTION get_current_bpm AS BYTE
    RETURN bpmLookup(gTempoIndex)
END FUNCTION


' =============================================================================
' PLAY_CHUNK_ASM_REV
' Come play_chunk_asm ma legge il chunk al contrario.
' gWaveBase deve puntare all ULTIMO byte del chunk (non al primo).
' Step e POSITIVO (non negato): la routine lo sottrae tramite NEGA+LEAU.
'
' Tecnica decremento:
'   ABX usa ACCB come UNSIGNED -> non puo fare decremento.
'   LEAU A,U usa A come SIGNED 8-bit -> NEGA + LEAU A,U decrementa.
'   Es: step=1.0 -> A=1 -> NEGA -> A=$FF (-1) -> LEAU A,U -> U-=1. Corretto.
'
' Registro U usato come puntatore (X resta libero per ugBasic).
' Overhead vs play_chunk_asm: +2 cicli/sample (NEGA) = ~5% su 6kHz.
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
