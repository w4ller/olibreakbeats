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

    ' Calcola il nuovo delay inversamente proporzionale ai BPM
    ' Se 150 BPM -> delay 24
    ' Allora targetBPM -> delay = 24 * (150 / targetBPM)
    newDelay = (24 * baseBPM) / targetBPM  :' = 3600 / targetBPM

    ' Limita il range per sicurezza
    IF newDelay < 12 THEN newDelay = 12  :' max 300 BPM
    IF newDelay > 48 THEN newDelay = 48  :' min 75 BPM

    gPlaybackDelay(0) = newDelay

    ' Salva il fattore per compensazione step
    gTempoFactor = (targetBPM * 128) / baseBPM
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
    DIM addr AS ADDRESS
    DIM sz AS INTEGER
    DIM wId AS BYTE
    DIM reps AS BYTE
    DIM r AS BYTE

    IF waveId = $FF THEN
        wId = RND(4)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

    sz = 9600 / chunkDiv
    addr = waveAddress(wId) + (sz * actualIdx)

    gWavBank(0) = wavBank(wId)
    gStepHi(0) = stepHi
    gStepLo(0) = stepLo
    gChunkSize(0) = gMinChunkSize / 256
    gChunkSize(1) = gMinChunkSize AND $FF

    reps = sz / gMinChunkSize

    FOR r = 1 TO reps
        gWaveBase(0) = addr / 256
        gWaveBase(1) = addr AND $FF
        CALL play_chunk_asm
        addr = addr + gMinChunkSize
    NEXT r
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
    DIM reps      AS BYTE

    IF waveId = $FF THEN
        wId = RND(4)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

    sz = 9600 / chunkDiv

    addr = waveAddress(wId) + (sz * actualIdx) + sz - 1

    gWavBank(0)   = wavBank(wId)
    gStepHi(0)    = stepHi
    gStepLo(0)    = stepLo
    gChunkSize(0) = gMinChunkSize / 256
    gChunkSize(1) = gMinChunkSize AND $FF

    reps = sz / gMinChunkSize

    WHILE reps > 0
        gWaveBase(0) = addr / 256
        gWaveBase(1) = addr AND $FF

        CALL play_chunk_asm_rev

        reps = reps - 1
        IF reps > 0 THEN
            addr = addr - gMinChunkSize
        ENDIF
    WEND
END PROC

' =============================================================================
' PLAY_SUBCHUNK
' Suona un subchunk arbitrario via player ASM.
' addr      = indirizzo di inizio subchunk (forward) oppure ultimo byte (reverse)
' size      = lunghezza del subchunk in sample
' stepHi/Lo = step 8.8
' bankId    = bank wave
' doRev     = 0 forward, 1 reverse
' =============================================================================
PROCEDURE play_subchunk[addr AS ADDRESS, size AS INTEGER, stepHi AS BYTE, stepLo AS BYTE, bankId AS BYTE, doRev AS BYTE]
    gWavBank(0) = bankId

    gWaveBase(0) = addr / 256
    gWaveBase(1) = addr AND $FF

    gChunkSize(0) = size / 256
    gChunkSize(1) = size AND $FF

    gStepHi(0) = stepHi
    gStepLo(0) = stepLo

    IF doRev = 0 THEN
        CALL play_chunk_asm
    ELSE
        CALL play_chunk_asm_rev
    ENDIF
END PROC


' =============================================================================
' PLAY_NOTE_EX  [chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode, reverseMode]
' Wrapper unico che combina reverse e stutter.
'
' reverseMode:
'   0   = forward
'   1   = reverse
'   $FF = random forward/reverse
'
' stutterMode:
'   00..0B = usa le tabelle globali stutterReps / stutterDeltaHi / stutterDeltaLo
'   $FF    = random 0..11
'
' Logica:
'   - il chunk selezionato viene sempre ridotto al chunk minimo (gMinChunkSize)
'   - se c'è stutter, il chunk minimo viene diviso in reps slice
'   - ogni slice viene suonata separatamente dal player ASM
' =============================================================================
PROCEDURE play_note_ex[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE, reverseMode AS BYTE]
    DIM doRev AS BYTE
    DIM sm AS BYTE
    DIM reps AS BYTE
    DIM r AS BYTE

    DIM actualIdx AS BYTE
    DIM wId AS BYTE

    DIM sz AS INTEGER
    DIM targetSize AS INTEGER
    DIM subSize AS INTEGER

    DIM baseAddr AS ADDRESS
    DIM playAddr AS ADDRESS

    DIM curHi AS BYTE
    DIM curLo AS BYTE
    DIM dHi AS BYTE
    DIM dLo AS BYTE

    DIM adjustedHi AS BYTE
    DIM adjustedLo AS BYTE
    DIM tempProduct AS INTEGER
    DIM product AS INTEGER
    DIM fracCarry AS INTEGER

    IF waveId = $FF THEN
        wId = RND(4)
    ELSE
        wId = waveId
    ENDIF

    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF

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

    tempProduct = (stepHi * 256 + stepLo) * 128 / gTempoFactor
    adjustedHi = tempProduct / 256
    adjustedLo = tempProduct AND $FF

    reps = stutterReps(sm)

    IF reps = 1 THEN
        IF doRev = 0 THEN
            play_note[actualIdx, chunkDiv, adjustedHi, adjustedLo, wId]
        ELSE
            play_note_rev[actualIdx, chunkDiv, adjustedHi, adjustedLo, wId]
        ENDIF
    ELSE
        sz = 9600 / chunkDiv
        baseAddr = waveAddress(wId) + (sz * actualIdx)

        targetSize = sz / reps
        IF targetSize >= gMinChunkSize THEN
            subSize = gMinChunkSize
        ELSE
            subSize = targetSize
        ENDIF

        curHi = adjustedHi
        curLo = adjustedLo
        dHi = stutterDeltaHi(sm)
        dLo = stutterDeltaLo(sm)

        FOR r = 0 TO reps - 1
            IF doRev = 0 THEN
                playAddr = baseAddr
                CALL play_subchunk[playAddr, subSize, curHi, curLo, wavBank(wId), 0]
            ELSE
                playAddr = baseAddr + sz - 1 
                CALL play_subchunk[playAddr, subSize, curHi, curLo, wavBank(wId), 1]
            ENDIF

            fracCarry = (curLo * dLo) / 256
            product = (curHi * dHi * 256) + (curHi * dLo) + (curLo * dHi) + fracCarry
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

