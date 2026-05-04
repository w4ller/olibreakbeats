' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test minimo: chiama play_note direttamente con valori fissi.
' Bypass completo di read_header e play_pattern.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

DO
    ' div=4, idx=0, stepHi=1, stepLo=0  -> slice 0 di 4, pitch 1.0x
    play_note[0, 4, 1, 0]
LOOP
