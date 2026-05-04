' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: play_pattern legge da gPat e gNNotes globali.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

gPat(0)  = $FF : gPat(1)  = 4 : gPat(2)  = 1 : gPat(3)  = 0
gPat(4)  = $FF : gPat(5)  = 4 : gPat(6)  = 1 : gPat(7)  = 0
gPat(8)  = $FF : gPat(9)  = 4 : gPat(10) = 1 : gPat(11) = 0
gPat(12) = $FF : gPat(13) = 4 : gPat(14) = 1 : gPat(15) = 0
gNNotes(0) = 4

DO
    CALL play_pattern
LOOP
