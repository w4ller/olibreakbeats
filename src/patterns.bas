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
' PREROLL_ROW
' Risolve tutti i valori $FF di gRow in valori concreti PRIMA del playback.
' Chiamata da play_pattern dopo la BANK READ della row, prima di play_note_ex.
' In questo modo play_note_ex non esegue nessuna RND durante l'audio:
' l'overhead e' costante -> BPM stabili anche con idx/wave/stutter casuali.
'
' gRow layout: [div, idx, stepHi, stepLo, waveId, stutterMode, reverseMode, prob]
' =============================================================================
PROCEDURE preroll_row
    ' --- waveId: $FF -> random 0..4 ---
    IF gRow(4) = $FF THEN
        gRow(4) = RND(5)
    ENDIF

    ' --- stutterMode: risolve i codici RND-range ---
    IF gRow(5) = $FF THEN         :' full random 0..11
        gRow(5) = RND(12)
    ELSE IF gRow(5) = $FE THEN    :' pitch-up range 4..7
        gRow(5) = 4 + RND(4)
    ELSE IF gRow(5) = $FD THEN    :' pitch-down range 8..11
        gRow(5) = 8 + RND(4)
    ELSE IF gRow(5) = $FC THEN    :' pitch range 4..11
        gRow(5) = 4 + RND(8)
    ELSE IF gRow(5) = $FB THEN    :' flat stutter range 0..3
        gRow(5) = RND(4)
    ENDIF

    ' --- reverseMode: $FF -> random 0 o 1 ---
    IF gRow(6) = $FF THEN
        gRow(6) = RND(2)
    ENDIF

    ' --- idx: $FF -> random 0..div-1 ---
    ' Risolto per ultimo perche dipende da div (gRow(0)).
    ' Anche il branch stutter in play_note_ex usava un secondo RND(chunkDiv):
    ' ora trova sempre un valore concreto, nessuna RND durante l'audio.
    IF gRow(1) = $FF THEN
        gRow(1) = RND(gRow(0))
    ENDIF
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
' Keyboard input is checked after each row via check_key + handle_key.
' Exits immediately if gModeStop=1 (tasto S) o gPatChanged=1 (1-9/N/P).
' =============================================================================
PROCEDURE play_pattern
    DIM i    AS BYTE
    DIM prob AS BYTE

    i = 0
    DO
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + gPatOffset + (i * 8) TO VARPTR(gRow) SIZE 8
        CALL preroll_row  :' risolve tutti i $FF prima dell'audio

        prob = gRow(7)

        IF prob = 255 THEN
            play_note_ex[gRow(1), gRow(0), gRow(2), gRow(3), gRow(4), gRow(5), gRow(6)]
        ELSE IF prob > 0 THEN
            IF RND(256) <= prob THEN
                play_note_ex[gRow(1), gRow(0), gRow(2), gRow(3), gRow(4), gRow(5), gRow(6)]
            ENDIF
        ENDIF

        CALL check_key
        CALL handle_key

        i = i + 1
    LOOP WHILE i < gNRows AND gModeStop = 0 AND gPatChanged = 0
END PROC
