' =============================================================================
' patterns.bas - pattern reader and sequencer
' =============================================================================


' =============================================================================
' LOAD_PATTERN[patIdx]
' Legge il pattern patIdx da patterns.bin e lo copia in gPat/gNNotes.
' Usa BANK READ - niente ASM, niente bank swap manuale.
' patIdx e 1-based.
' =============================================================================
PROCEDURE load_pattern[patIdx AS BYTE]
    DIM offA   (2) AS BYTE FOR BANK READ
    DIM offB   (2) AS BYTE FOR BANK READ
    DIM chunk  (4) AS BYTE FOR BANK READ
    DIM prev   AS INTEGER
    DIM next   AS INTEGER
    DIM nNotes AS BYTE
    DIM i      AS BYTE

    ' Leggi offset di patIdx
    BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + (1 + (patIdx-1)*2) TO VARPTR(offA) SIZE 2
    prev = PEEKW(VARPTR(offA))

    ' Leggi offset del pattern successivo, oppure usa fine file
    IF patIdx < gNPat(0) THEN
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + (1 + patIdx*2) TO VARPTR(offB) SIZE 2
        next = PEEKW(VARPTR(offB))
    ELSE
        next = SIZE(patFile)
    END IF

    nNotes = (next - prev) \ 4
    IF nNotes > 16 THEN nNotes = 16
    gNNotes(0) = nNotes

    ' Copia note in gPat
    FOR i = 0 TO nNotes - 1
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + prev + (i*4) TO VARPTR(chunk) SIZE 4
        gPat(i*4)   = chunk(0)
        gPat(i*4+1) = chunk(1)
        gPat(i*4+2) = chunk(2)
        gPat(i*4+3) = chunk(3)
    NEXT i
END PROC


' =============================================================================
' PLAY_PATTERN
' Suona gNNotes note dall array globale gPat.
' Formato: [div, idx, stepHi, stepLo] x gNNotes
' =============================================================================
PROCEDURE play_pattern
    DIM n AS BYTE
    FOR n = 0 TO gNNotes(0) - 1
        play_note[gPat(n*4), gPat(n*4+1), gPat(n*4+2), gPat(n*4+3)]
    NEXT n
END PROC
