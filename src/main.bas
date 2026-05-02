' =============================================================================
' olibreakbeats - main.bas   v0.8  (Passo 6 fix)
' Thomson MO6 / UGBasic / Motorola 6809
'
' v0.8: fix dichiarazioni FOR BANK READ.
' Variabili a 2 byte (ADDRESS/INTEGER) -> DIM x(2) AS BYTE FOR BANK READ
' x(0)=hi x(1)=lo, contigui, big-endian come si aspetta LDX/LDY su 6809.
' Variabili a 1 byte                   -> DIM x(1) AS BYTE FOR BANK READ
' Tutte sotto $6000, sicure da bank swap.
' =============================================================================


' --- Assets BANKED ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED


' --- Interfaccia ASM player WAV (sotto $6000) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase  : ' ADDRESS hi/lo
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize : ' INTEGER hi/lo
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Interfaccia ASM lettura pattern (sotto $6000) ---
DIM gPatBank   (1) AS BYTE FOR BANK READ : GLOBAL gPatBank
DIM gPatPtr    (2) AS BYTE FOR BANK READ : GLOBAL gPatPtr    : ' ADDRESS hi/lo
DIM gNoteDiv   (1) AS BYTE FOR BANK READ : GLOBAL gNoteDiv
DIM gNoteIdx   (1) AS BYTE FOR BANK READ : GLOBAL gNoteIdx
DIM gNoteShi   (1) AS BYTE FOR BANK READ : GLOBAL gNoteShi
DIM gNoteSlo   (1) AS BYTE FOR BANK READ : GLOBAL gNoteSlo


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
' READ_NOTE_ASM
' Legge 4 byte da gPatPtr nel banco gPatBank.
' Risultati in gNoteDiv, gNoteIdx, gNoteShi, gNoteSlo.
' =============================================================================
PROC read_note_asm
    ON CPU6809 BEGIN ASM
        LDA   _gPatBank
        STA   $A7E5
        LDX   _gPatPtr
        LDA   0,X
        STA   _gNoteDiv
        LDA   1,X
        STA   _gNoteIdx
        LDA   2,X
        STA   _gNoteShi
        LDA   3,X
        STA   _gNoteSlo
        LDA   #7
        STA   $A7E5
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
' chunkIdx=$FF -> chunk casuale tra 0..chunkDiv-1
' =============================================================================
PROCEDURE play_note[chunkIdx AS BYTE, chunkDiv AS BYTE, stepHi AS BYTE, stepLo AS BYTE]
    DIM actualIdx AS BYTE
    DIM addr      AS ADDRESS
    DIM sz        AS INTEGER
    IF chunkIdx = $FF THEN
        actualIdx = RND(chunkDiv)
    ELSE
        actualIdx = chunkIdx
    ENDIF
    sz             = 9600 / chunkDiv
    gChunkSize(0)  = sz / 256
    gChunkSize(1)  = sz AND $FF
    addr           = VARBANKPTR(wave) + (sz * actualIdx)
    gWaveBase(0)   = addr / 256
    gWaveBase(1)   = addr AND $FF
    gWavBank(0)    = VARBANK(wave)
    gStepHi(0)     = stepHi
    gStepLo(0)     = stepLo
    CALL play_chunk_asm
END PROC


' =============================================================================
' Main
' =============================================================================
CALL init_dac

' --- Leggi header patterns.bin ---
gPatBank(0) = VARBANK(patFile)
DIM tmp     AS ADDRESS : tmp = VARBANKPTR(patFile)
gPatPtr(0)  = tmp / 256
gPatPtr(1)  = tmp AND $FF
CALL read_note_asm

DIM nPat       AS BYTE    : nPat       = gNoteDiv(0)
DIM offHi      AS BYTE    : offHi      = gNoteIdx(0)
DIM offLo      AS BYTE    : offLo      = gNoteShi(0)
DIM pat1Off    AS INTEGER : pat1Off    = offHi * 256 + offLo
DIM fileSize   AS INTEGER : fileSize   = SIZE(patFile)
DIM totalNotes AS INTEGER : totalNotes = (fileSize - pat1Off) / 4
DIM basePtr    AS ADDRESS : basePtr    = VARBANKPTR(patFile) + pat1Off

DIM n AS INTEGER

DO
    FOR n = 0 TO totalNotes - 1
        tmp        = basePtr + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        play_note[gNoteIdx(0), gNoteDiv(0), gNoteShi(0), gNoteSlo(0)]
    NEXT n
LOOP
