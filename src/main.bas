' =============================================================================
' olibreakbeats - main.bas
' Startup: init + wait for key input to select playback mode.
' A = play all patterns, 1-9 = single pattern loop
' S = stop, N = next, P = previous
' check_key + handle_key called inside play_pattern after each row.
' gPatChanged=1 causes immediate exit from play_pattern (pattern switch).
' gModeStop=1 causes stop; check_key/handle_key polled in idle state.
' =============================================================================
CLS

INCLUDE "src/globals.bas"   
INCLUDE "src/player_asm.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/player.bas"
INCLUDE "src/input.bas"
INCLUDE "src/patterns.bas"

CALL init_dac
CALL init_waves
CALL init_stutter
CALL init_patterns
CALL init_tempo

gCurPattern = 0
gModeAll    = 0
gModeStop   = 0
gPatChanged = 0
set_tempo[150]

DO
    IF gModeStop = 0 THEN
        gPatChanged = 0  :' reset prima di ogni ciclo di play
        IF gModeAll = 1 THEN
            CALL load_pattern[gCurPattern]
            CALL play_pattern
            IF gPatChanged = 0 THEN  :' avanza al pattern successivo solo se non c'e' stato cambio manuale
                IF gCurPattern < gNPat(0) - 1 THEN
                    gCurPattern = gCurPattern + 1
                ELSE
                    gCurPattern = 0
                ENDIF
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
