' =============================================================================
' patterns.bas - pattern reader and sequencer
' =============================================================================


' =============================================================================
' INIT_PATTERNS
' Reads byte 0 of patterns.bin and stores the pattern count in gNPat.
' Must be called once at startup, before any call to load_pattern.
' =============================================================================
PROCEDURE init_patterns
    DIM tmp (1) AS BYTE FOR BANK READ
    BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(tmp) SIZE 1
    gNPat(0) = tmp(0)
END PROC


' =============================================================================
' LOAD_PATTERN[patIdx]
' Reads the 3-byte header entry for pattern patIdx and stores:
'   gPatOffset  = absolute offset of the first data byte in the file
'   gNRows      = number of rows in the pattern
' No audio data is loaded here: rows are read one by one inside play_pattern.
' patIdx is 0-based (0 = first pattern).
' =============================================================================
PROCEDURE load_pattern[patIdx AS BYTE]
    DIM hdr  (3) AS BYTE FOR BANK READ
    DIM base AS INTEGER

    ' Header entry layout: [offHi, offLo, rowCount]
    ' base = 1 (skip N byte) + patIdx * 3
    base = 1 + patIdx * 3
    BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + base TO VARPTR(hdr) SIZE 3

    gPatOffset = (hdr(0) * 256) + hdr(1)
    gNRows     = hdr(2)
END PROC


' =============================================================================
' PLAY_PATTERN
' Plays the current pattern row by row, reading directly from the BANK.
' For each row: reads 8 bytes into gRow, passes all 6 fields to play_note_stutter.
' Row format: [div, idx, stepHi, stepLo, waveId, stutterMode, 0, 0]
'   waveId=0..$04      = fixed wave; $FF = random wave
'   stutterMode=$00    = no stutter (1x, default)
'   stutterMode=$01    = stutter 2x
'   stutterMode=$02    = stutter 4x
'   stutterMode=$03    = stutter 8x
'   stutterMode=$FF    = random stutter (1x/2x/4x)
' Byte gRow(6..7) are reserved and ignored.
' =============================================================================
PROCEDURE play_pattern
    DIM i AS BYTE
    FOR i = 0 TO gNRows - 1
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + gPatOffset + (i * 8) TO VARPTR(gRow) SIZE 8
        play_note_stutter[gRow(1), gRow(0), gRow(2), gRow(3), gRow(4), gRow(5)]
    NEXT i
END PROC
