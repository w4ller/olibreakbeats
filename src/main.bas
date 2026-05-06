' =============================================================================
' olibreakbeats - main.bas
' Avvio: init_patterns legge gNPat, load_pattern carica header pattern 0,
' play_pattern suona in loop leggendo una riga alla volta dal BANK.
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/player.bas"
INCLUDE "src/patterns.bas"


CALL init_dac

' Leggi numero pattern totali dal byte 0 di patterns.bin
CALL init_patterns

' Carica header del pattern 0 (primo pattern, 0-based)


DO
    FOR n = 0 TO gNPat(0) - 1
        CALL load_pattern[n]
        CALL play_pattern
    NEXT
   
LOOP
