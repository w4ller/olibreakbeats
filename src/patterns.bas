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
' READ_HEADER
' Parses patterns.bin header once at startup.
' Populates gNPat and gPatternOffset(1..N+1).
'
' gPatternOffset layout (2 byte per slot, hi/lo):
'   slot i  -> absolute RAM address of pattern i data
'   slot N+1-> address of first byte past last pattern (= VARBANKPTR + fileSize)
'
' After read_header, switching pattern is just:
'   gCurPat(0) = desired_pattern (1-based)
' =============================================================================
PROC read_header
    DIM i        AS BYTE
    DIM fileOff  AS INTEGER   :' offset dentro il file (big-endian WORD dal file)
    DIM ramAddr  AS ADDRESS   :' indirizzo RAM assoluto
    DIM tmp      AS ADDRESS
    DIM base     AS ADDRESS   :' VARBANKPTR(patFile), calcolato una volta
    DIM slotIdx  AS INTEGER   :' indice byte dentro gPatternOffset (i*2)

    gPatBank(0) = VARBANK(patFile)
    base        = VARBANKPTR(patFile)

    ' --- Leggi N (byte 0 del file) ---
    tmp        = base
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_byte_asm
    gNPat(0) = gNoteDiv(0)

    ' --- Per ogni pattern leggi l'offset dal file e precalcola l'indirizzo RAM ---
    FOR i = 1 TO gNPat(0)
        ' Offset del pattern i nell'offset table: byte 1 + (i-1)*2  [hi]
        '                                          byte 2 + (i-1)*2  [lo]
        tmp        = base + 1 + (i - 1) * 2
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_byte_asm
        DIM hiB AS BYTE : hiB = gNoteDiv(0)

        tmp        = tmp + 1
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_byte_asm
        DIM loB AS BYTE : loB = gNoteDiv(0)

        fileOff = hiB * 256 + loB
        ramAddr = base + fileOff

        ' Scrivi in gPatternOffset: slot i = byte (i-1)*2 e (i-1)*2+1
        slotIdx = (i - 1) * 2
        gPatternOffset(slotIdx)     = ramAddr / 256
        gPatternOffset(slotIdx + 1) = ramAddr AND $FF
    NEXT i

    ' --- Sentinella: slot N+1 = base + fileSize ---
    ramAddr = base + SIZE(patFile)
    slotIdx = gNPat(0) * 2
    gPatternOffset(slotIdx)     = ramAddr / 256
    gPatternOffset(slotIdx + 1) = ramAddr AND $FF

    ' --- Parte dal pattern 1 ---
    gCurPat(0) = 1
END PROC


' =============================================================================
' PLAY_PATTERN
' Plays all notes of the current pattern (gCurPat) once.
' Note count = (offset[curPat+1] - offset[curPat]) / 4
' =============================================================================
PROCEDURE play_pattern
    DIM n          AS INTEGER
    DIM slotIdx    AS INTEGER
    DIM baseAddr   AS ADDRESS
    DIM nextAddr   AS ADDRESS
    DIM totalNotes AS INTEGER
    DIM tmp        AS ADDRESS

    slotIdx  = (gCurPat(0) - 1) * 2
    baseAddr = gPatternOffset(slotIdx) * 256 + gPatternOffset(slotIdx + 1)

    slotIdx  = gCurPat(0) * 2
    nextAddr = gPatternOffset(slotIdx) * 256 + gPatternOffset(slotIdx + 1)

    totalNotes = (nextAddr - baseAddr) / 4

    FOR n = 0 TO totalNotes - 1
        tmp        = baseAddr + n * 4
        gPatPtr(0) = tmp / 256
        gPatPtr(1) = tmp AND $FF
        CALL read_note_asm
        play_note[gNoteIdx(0), gNoteDiv(0), gNoteShi(0), gNoteSlo(0)]
    NEXT n
END PROC
