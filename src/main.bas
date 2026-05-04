' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: 4 slice dell'amen in sequenza, valori hardcodati.
' Bypass completo di read_header e play_pattern.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

DO
    play_note[0, 4, 1, 0]
    play_note[1, 4, 1, 0]
    play_note[2, 4, 1, 0]
    play_note[3, 4, 1, 0]
LOOP
