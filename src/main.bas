' =============================================================================
' olibreakbeats - main.bas   v0.8
' Thomson MO6 / ugBASIC / Motorola 6809
'
' Pattern-driven generative breakbeat player.
' Reads patterns.bin directly from banked RAM via ASM (no buffer).
'
' *** IMPORTANT - BANK SWAP MEMORY RULE ***
' Any variable read or written during a bank swap MUST live below $6000.
' The region $6000-$7FFF is the banked window: switching banks remaps it,
' corrupting any variables stored there.
' Rule:
'   1-byte vars  -> DIM x(1) AS BYTE FOR BANK READ : GLOBAL x
'   2-byte vars  -> DIM x(2) AS BYTE FOR BANK READ : GLOBAL x  (hi=x(0), lo=x(1))
' All ASM interface globals below follow this rule.
'
' patterns.bin format:
'   byte 0        : N = number of patterns (1..255)
'   byte 1..2     : absolute offset of pattern 1 (big-endian WORD)
'   byte 3..4     : absolute offset of pattern 2 (if N>1)
'   ...
'   data section  : notes, 4 bytes each: DIV  IDX  STEP_HI  STEP_LO
'                   IDX=$FF = random chunk (0..DIV-1) chosen at runtime
'
' Step 8.8 fixed-point pitch:
'   $0100 = 1.0x  original pitch
'   $0200 = 2.0x  octave up
'   $0180 = 1.5x  fifth up
'   $0080 = 0.5x  octave down
' =============================================================================


' --- Banked assets ---
GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED


' --- WAV player ASM interface (all below $6000, safe from bank swap) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase  : ' ADDRESS hi/lo
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize : ' INTEGER hi/lo
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Pattern reader ASM interface (all below $6000, safe from bank swap) ---
DIM gPatBank   (1) AS BYTE FOR BANK READ : GLOBAL gPatBank
DIM gPatPtr    (2) AS BYTE FOR BANK READ : GLOBAL gPatPtr    : ' ADDRESS hi/lo
DIM gNoteDiv   (1) AS BYTE FOR BANK READ : GLOBAL gNoteDiv
DIM gNoteIdx   (1) AS BYTE FOR BANK READ : GLOBAL gNoteIdx
DIM gNoteShi   (1) AS BYTE FOR BANK READ : GLOBAL gNoteShi
DIM gNoteSlo   (1) AS BYTE FOR BANK READ : GLOBAL gNoteSlo


' =============================================================================
' INIT_DAC
' Enables the DAC output on the MO6 sound chip.
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
' Reads 4 bytes from banked RAM at gPatPtr into gNoteDiv/Idx/Shi/Slo.
' Does NOT advance gPatPtr (caller does it).
' Bank is restored to 7 after the read.
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


' =============================================================================
' Main
' =============================================================================
CALL init_dac

' --- Parse patterns.bin header from banked RAM ---
' Reuse read_note_asm: first 4 bytes are N | off_hi | off_lo | (ignored)
gPatBank(0) = VARBANK(patFile)
DIM tmp     AS ADDRESS : tmp = VARBANKPTR(patFile)
gPatPtr(0)  = tmp / 256
gPatPtr(1)  = tmp AND $FF
CALL read_note_asm

DIM nPat       AS BYTE    : nPat       = gNoteDiv(0)               :' number of patterns
DIM offHi      AS BYTE    : offHi      = gNoteIdx(0)               :' pattern 1 offset high
DIM offLo      AS BYTE    : offLo      = gNoteShi(0)               :' pattern 1 offset low
DIM pat1Off    AS INTEGER : pat1Off    = offHi * 256 + offLo       :' absolute offset
DIM fileSize   AS INTEGER : fileSize   = SIZE(patFile)
DIM totalNotes AS INTEGER : totalNotes = (fileSize - pat1Off) / 4  :' notes in pattern 1
DIM basePtr    AS ADDRESS : basePtr    = VARBANKPTR(patFile) + pat1Off

DIM n AS INTEGER

' --- Main loop: play pattern 1 forever ---
DO
    FOR n = 0 TO totalNotes - 1
        tmp        = basePtr + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        play_note[gNoteIdx(0), gNoteDiv(0), gNoteShi(0), gNoteSlo(0)]
    NEXT n
LOOP
