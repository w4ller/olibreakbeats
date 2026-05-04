' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: load_pattern legge da patterns.bin, play_pattern suona da gPat.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

CALL load_pattern[1]

DO
    CALL play_pattern
LOOP
