' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Test: play_pattern legge da array hardcodato.
' Formato: [idx, div, stepHi, stepLo] x N note
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

' Pattern hardcodato: 4 note, [idx, div, stepHi, stepLo]
DIM pat(16) AS BYTE
pat(0)  = 0 : pat(1)  = 4 : pat(2)  = 1 : pat(3)  = 0
pat(4)  = 1 : pat(5)  = 4 : pat(6)  = 1 : pat(7)  = 0
pat(8)  = 2 : pat(9)  = 4 : pat(10) = 1 : pat(11) = 0
pat(12) = 3 : pat(13) = 4 : pat(14) = 1 : pat(15) = 0

DIM n AS BYTE

DO
    FOR n = 0 TO 3
        play_note[pat(n*4), pat(n*4+1), pat(n*4+2), pat(n*4+3)]
    NEXT n
LOOP
