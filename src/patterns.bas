' =============================================================================
' patterns.bas - pattern reader and sequencer
' =============================================================================

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
' READ_BYTE_ASM
' Reads 1 byte from banked RAM at gPatPtr into gNoteDiv(0).
' Used only at init (read_header) - speed not critical.
' Bank is restored to 7 after the read.
' =============================================================================
PROC read_byte_asm
    ON CPU6809 BEGIN ASM
        LDA   _gPatBank
        STA   $A7E5
        LDX   _gPatPtr
        LDA   0,X
        STA   _gNoteDiv
        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC


' =============================================================================
' TEST DATA - hardcoded pattern (4 notes x 4 bytes)
' Format: [div][idx][stepHI][stepLO]
' chunkDiv=4 -> IDX validi: 0,1,2,3
' step $01,$00 = 1.0x pitch originale
' TODO: remove after crash isolation test
' =============================================================================
DIM testPattern(16) AS BYTE : GLOBAL testPattern

testPattern(0)  = 4 : testPattern(1)  = 0 : testPattern(2)  = 1 : testPattern(3)  = 0
testPattern(4)  = 4 : testPattern(5)  = 1 : testPattern(6)  = 1 : testPattern(7)  = 0
testPattern(8)  = 4 : testPattern(9)  = 2 : testPattern(10) = 1 : testPattern(11) = 0
testPattern(12) = 4 : testPattern(13) = 3 : testPattern(14) = 1 : testPattern(15) = 0


' =============================================================================
' READ_HEADER
' TODO: restore original body after crash isolation test.
' Currently bypasses patterns.bin and points gPatternOffset at testPattern.
' =============================================================================
PROC read_header
    DIM addr AS INTEGER

    ' === HARDCODED BYPASS - rimuovere dopo il test ===
    addr = VARPTR(testPattern(0))

    gNPat(0) = 1

    gPatternOffset(0) = addr / 256
    gPatternOffset(1) = addr - (gPatternOffset(0) * 256)

    addr = addr + 16
    gPatternOffset(2) = addr / 256
    gPatternOffset(3) = addr - (gPatternOffset(2) * 256)

    gCurPat(0) = 1
    ' === FINE HARDCODED BYPASS ===
END PROC


' =============================================================================
' PLAY_PATTERN
' Plays all notes of the current pattern (gCurPat) once.
' Note count = (offset[curPat+1] - offset[curPat]) / 4
'
' FIX: gPatternOffset contiene byte separati hi/lo.
' ugBASIC tronca "BYTE * 256" a 8 bit prima di assegnare.
' Soluzione: copia hi/lo in variabili INTEGER prima di fare l aritmetica.
' =============================================================================
PROCEDURE play_pattern
    DIM n          AS INTEGER
    DIM slotIdx    AS INTEGER
    DIM tmpHi      AS INTEGER
    DIM tmpLo      AS INTEGER
    DIM baseAddr   AS ADDRESS
    DIM nextAddr   AS ADDRESS
    DIM totalNotes AS INTEGER
    DIM tmp        AS ADDRESS

    ' baseAddr: leggi slot (curPat-1)*2 e (curPat-1)*2+1
    slotIdx  = (gCurPat(0) - 1) * 2
    tmpHi    = gPatternOffset(slotIdx)
    tmpLo    = gPatternOffset(slotIdx + 1)
    baseAddr = tmpHi * 256 + tmpLo

    ' nextAddr: leggi slot curPat*2 e curPat*2+1
    slotIdx  = gCurPat(0) * 2
    tmpHi    = gPatternOffset(slotIdx)
    tmpLo    = gPatternOffset(slotIdx + 1)
    nextAddr = tmpHi * 256 + tmpLo

    totalNotes = (nextAddr - baseAddr) / 4

    FOR n = 0 TO totalNotes - 1
        tmp        = baseAddr + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        play_note[gNoteIdx(0), gNoteDiv(0), gNoteShi(0), gNoteSlo(0)]
    NEXT n
END PROC
