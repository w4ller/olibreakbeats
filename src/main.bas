' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: play_pattern legge da array globale gPat.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

DIM gPat(16) AS BYTE : GLOBAL gPat
gPat(0)  = 0 : gPat(1)  = 4 : gPat(2)  = 1 : gPat(3)  = 0
gPat(4)  = 1 : gPat(5)  = 4 : gPat(6)  = 1 : gPat(7)  = 0
gPat(8)  = 2 : gPat(9)  = 4 : gPat(10) = 1 : gPat(11) = 0
gPat(12) = 3 : gPat(13) = 4 : gPat(14) = 1 : gPat(15) = 0

DO
    play_pattern[4]
LOOP
