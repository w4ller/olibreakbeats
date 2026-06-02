' =============================================================================
' olibreakbeats - main.bas
' Startup: init + wait for key input to select playback mode.
' A = play all patterns, 1-9 = single pattern loop
' S = stop, N = next, P = previous
' check_key + handle_key are called inside play_pattern after each row.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/player.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/input.bas"

CALL init_dac
CALL init_waves
CALL init_stutter
CALL init_patterns

gCurPattern = 0
gModeAll    = 0
gModeStop   = 0

DO
    IF gModeStop = 0 THEN
        IF gModeAll = 1 THEN
            CALL load_pattern[gCurPattern]
            CALL play_pattern
            IF gCurPattern < gNPat(0) - 1 THEN
                gCurPattern = gCurPattern + 1
            ELSE
                gCurPattern = 0
            ENDIF
        ELSE
            CALL load_pattern[gCurPattern]
            CALL play_pattern
        ENDIF
    ELSE
        CALL check_key
        CALL handle_key
    ENDIF
LOOP
