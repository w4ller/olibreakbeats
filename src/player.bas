' Parametri per play_chunk_atomic (oltre a quelli esistenti)
DIM gReps(1) AS BYTE FOR BANK READ : GLOBAL gReps      :' 1..4, numero sotto-ripetizioni stutter
DIM gDeltaHi(1) AS BYTE FOR BANK READ : GLOBAL gDeltaHi    :' delta pitch per sotto-ripetizione
DIM gDeltaLo(1) AS BYTE FOR BANK READ : GLOBAL gDeltaLo
DIM gSubSize(1) AS WORD FOR BANK READ : GLOBAL gSubSize    :' 300/reps, dimensione sotto-chunk in sample
DIM gDoRev(1) AS BYTE FOR BANK READ : GLOBAL gDoRev
DIM chunkMin AS INT : GLOBAL chunkMin
DIM tmpReps(1) AS BYTE FOR BANK READ : GLOBAL tmpReps
chunkMin = 300

' =============================================================================
' PLAY_CHUNK_ATOMIC
' Suona sempre 300 sample (1/32), suddivisi in gReps sotto-blocchi (1..4)
' con pitch shift incrementale via gDeltaHi/gDeltaLo.
' Costo in cicli IDENTICO per gReps=1,2,3,4 (padding su reps basso).
' Forward/reverse selezionato da gDoRev.
' =============================================================================
PROC play_chunk_atomic
    ON CPU6809 BEGIN ASM
        LDA   _gWavBank
        STA   $A7E5

        LDA   _gReps
        STA   _tmpReps          ; contatore sotto-blocchi rimanenti

        LDX   _gWaveBase       ; forward: X punta all inizio
        LDU   _gWaveBase       ; reverse: U punta allo stesso indirizzo iniziale
                                ; (uno dei due sara usato in base a gDoRev)

REP_LOOP:
        LDY   _gSubSize         ; sample nel sotto-blocco corrente
        CLR   _gFracAcc

        LDA   _gDoRev
        BNE   SUB_REV

SUB_FWD:
        LDA   0,X
        STA   $A7CD
        LDB   #24
SF_DLY:
        DECB
        BNE   SF_DLY
        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDB   _gStepHi
        ADCB  #0
        ABX
        LEAY  -1,Y
        BNE   SUB_FWD
        BRA   AFTER_SUB

SUB_REV:
        LDA   0,U
        STA   $A7CD
        LDB   #24
SR_DLY:
        DECB
        BNE   SR_DLY
        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDA   _gStepHi
        ADCA  #0
        NEGA
        LEAU  A,U
        LEAY  -1,Y
        BNE   SUB_REV

AFTER_SUB:
        ; aggiorna pitch per prossimo sotto-blocco (shift-add, NON moltiplicazione BASIC)
        LDA   _gStepHi
        LDB   _gStepLo
        ; product = step + delta (approssimazione lineare accumulata)
        ADDB  _gDeltaLo
        ADCA  _gDeltaHi
        STA   _gStepHi
        STB   _gStepLo

        DEC   _tmpReps
        BNE   REP_LOOP

        LDA   #7
        STA   $A7E5
        RTS
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_NOTE_UNIFIED [chunkIdx, chunkDiv, stepHi, stepLo, waveId, stutterMode, reverseMode]
' Setup fatto in BASIC UNA SOLA VOLTA per nota (non introduce jitter cumulativo),
' poi loop dei mini-chunk da 300 sample tutto delegato ad ASM.
' =============================================================================
PROCEDURE play_note_unified[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE, waveId AS BYTE, stutterMode AS BYTE, reverseMode AS BYTE]
    DIM wId AS BYTE
    DIM actualIdx AS BYTE
    DIM sm AS BYTE
    DIM reps AS BYTE
    DIM addr AS ADDRESS
    DIM chunkSizeInSamples AS INTEGER
    DIM nMinimalChunks AS BYTE
    DIM i AS BYTE

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

    IF reverseMode = $FF THEN
        gDoRev(0) = RND(2)
    ELSE
        gDoRev(0) = reverseMode
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
    gReps(0) = reps
    gDeltaHi(0) = stutterDeltaHi(sm)
    gDeltaLo(0) = stutterDeltaLo(sm)

    gStepHi(0) = stepHi
    gStepLo(0) = stepLo
    gWavBank(0) = wavBank(wId)

    chunkSizeInSamples = 9600 / chunkDiv
    gSubSize(0) = (chunkSizeInSamples / chunkMin) : ' quanti mini-chunk da 300
    nMinimalChunks = chunkSizeInSamples / chunkMin

    addr = waveAddress(wId) + (actualIdx * chunkSizeInSamples)
    IF gDoRev(0) = 1 THEN
        addr = addr + chunkSizeInSamples - 1
    ENDIF

    FOR i = 0 TO nMinimalChunks - 1
        IF gDoRev(0) = 0 THEN
            gWaveBase(0) = (addr + (i * chunkMin)) / 256
            gWaveBase(1) = (addr + (i * chunkMin)) AND $FF
        ELSE
            gWaveBase(0) = (addr - (i * chunkMin)) / 256
            gWaveBase(1) = (addr - (i * chunkMin)) AND $FF
        ENDIF

        gSubSize(0) = chunkMin / reps
        CALL play_chunk_atomic

        CALL check_key
        IF gModeStop = 1 OR gPatChanged = 1 THEN
            EXIT PROC
        ENDIF
    NEXT i
END PROC