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
' Row format: [div, idx, stepHi, stepLo, waveId, stutterMode, reverseMode, prob]
'   div         = chunk divisor (1 2 4 8 16 32 64)
'   idx         = chunk index (0..div-1) or $FF = random
'   stepHi/Lo   = 8.8 fixed-point pitch multiplier
'   waveId      = 0..4 fixed wave; $FF = random wave
'   stutterMode = $00 no stutter; $01..$0B modes; $FB..$FF RND sub-range
'   reverseMode = $00 forward; $01 reverse; $FF RND fwd/rev
'   prob        = probabilita esecuzione: 0=mai 1=~0.4% 13=~5%
'                 64=~25% 128=~50% 255=sempre (default)
'
' Logica probabilita:
'   prob=255 -> esegui sempre (fast path, nessuna chiamata RND)
'   prob=0   -> salta sempre
'   altri    -> esegui se RND(256) <= prob
'   RND(256) restituisce 0..255; prob=128 -> ~50.4% di esecuzione.
'
' check_key+handle_key vengono chiamati una volta per battuta (ogni 9600
' campioni emessi) anziche ogni row. Questo rende l'overhead di tastiera
' costante e indipendente da div/stutter, stabilizzando i BPM a 147.8
' su Furnace con qualsiasi combinazione di chunk.
' =============================================================================
PROCEDURE play_pattern
    DIM i        AS BYTE
    DIM prob     AS BYTE
    DIM rowSamps AS INTEGER  :' campioni emessi dalla row corrente

    i = 0
    DO
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + gPatOffset + (i * 8) TO VARPTR(gRow) SIZE 8

        prob = gRow(7)

        IF prob = 255 THEN
            play_note_ex[gRow(1), gRow(0), gRow(2), gRow(3), gRow(4), gRow(5), gRow(6)]
            rowSamps = 9600 / gRow(0)  :' div e' gRow(0)
        ELSE IF prob > 0 THEN
            IF RND(256) <= prob THEN
                play_note_ex[gRow(1), gRow(0), gRow(2), gRow(3), gRow(4), gRow(5), gRow(6)]
            ENDIF
            rowSamps = 9600 / gRow(0)
        ELSE
            rowSamps = 0  :' row saltata: prob=0, nessun campione emesso
        ENDIF

        gSamplesEmitted = gSamplesEmitted + rowSamps

        IF gSamplesEmitted >= 9600 THEN
            CALL check_key
            CALL handle_key
            gSamplesEmitted = gSamplesEmitted - 9600
        ENDIF

        i = i + 1
    LOOP WHILE i < gNRows AND gModeStop = 0 AND gPatChanged = 0
END PROC
