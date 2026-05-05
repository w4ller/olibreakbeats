' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: legge gNPat da file, carica pattern 1 con load_pattern, suona in loop.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

' Leggi numero pattern dal byte 0 di patterns.bin
DIM tmp(1) AS BYTE FOR BANK READ
BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(tmp) SIZE 1
gNPat(0) = tmp(0)

' Carica pattern 1 in gPat
CALL load_pattern[1]

DO
    CALL play_pattern
LOOP
