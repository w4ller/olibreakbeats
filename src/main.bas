' =============================================================================
' olibreakbeats - main.bas   v0.9
' Thomson MO6 / ugBASIC / Motorola 6809
'
' Pattern-driven generative breakbeat player.
' Reads patterns.bin directly from banked RAM via ASM (no buffer).
'
' Step 8.8 fixed-point pitch:
'   $0100 = 1.0x  original pitch
'   $0200 = 2.0x  octave up
'   $0180 = 1.5x  fifth up
'   $0080 = 0.5x  octave down
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac
CALL read_header

DO
    CALL play_pattern
LOOP
