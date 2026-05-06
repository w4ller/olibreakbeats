' =============================================================================
' olibreakbeats - main.bas
' Startup: init_patterns reads gNPat, then loops through all patterns
' calling load_pattern + play_pattern for each one.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/player.bas"
INCLUDE "src/patterns.bas"

CALL init_dac

' Read total pattern count from byte 0 of patterns.bin
CALL init_patterns

DO
    FOR n = 0 TO gNPat(0) - 1
        CALL load_pattern[n]
        CALL play_pattern
    NEXT
LOOP
