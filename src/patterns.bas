' =============================================================================
' patterns.bas - pattern reader and sequencer
' =============================================================================


' =============================================================================
' INIT_PATTERNS
' Legge il byte 0 di patterns.bin e salva il numero di pattern in gNPat.
' Va chiamata una volta sola all avvio, prima di qualsiasi load_pattern.
' =============================================================================
PROCEDURE init_patterns
    DIM tmp (1) AS BYTE FOR BANK READ
    BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(tmp) SIZE 1
    gNPat(0) = tmp(0)
END PROC


' =============================================================================
' LOAD_PATTERN[patIdx]
' Legge dall header i 3 byte del pattern patIdx e salva:
'   gPatOffset  = offset assoluto del primo byte dati nel file
'   gNRows      = numero di righe del pattern
' Non carica dati audio: la lettura avviene riga per riga in play_pattern.
' patIdx e' 0-based (0 = primo pattern).
' =============================================================================
PROCEDURE load_pattern[patIdx AS BYTE]
    DIM hdr (3) AS BYTE FOR BANK READ
    DIM base  AS INTEGER

    ' Ogni entry header = 3 byte: [offHi, offLo, rowCount]
    ' base = 1 (skip N) + patIdx * 3
    base = 1 + patIdx * 3
    BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + base TO VARPTR(hdr) SIZE 3

    gPatOffset = (hdr(0) * 256) + hdr(1)
    gNRows     = hdr(2)
END PROC


' =============================================================================
' PLAY_PATTERN
' Suona il pattern corrente riga per riga leggendo direttamente dal BANK.
' Per ogni riga legge 8 byte in gRow e passa i primi 4 a play_note.
' I byte gRow(4..7) sono riservati e ignorati.
' =============================================================================
PROCEDURE play_pattern
    DIM i AS BYTE
    FOR i = 0 TO gNRows - 1
        BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) + gPatOffset + (i * 8) TO VARPTR(gRow) SIZE 8
        play_note[gRow(1), gRow(0), gRow(2), gRow(3)]
    NEXT i
END PROC
