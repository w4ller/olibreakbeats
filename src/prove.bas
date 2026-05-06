' =============================================================================
' prove.bas - test ISOLATO play_pattern
' Header hardcodato in patterns.bas (testPattern/read_header bypass).
' NON legge patterns.bin.
' Stampa i valori calcolati da read_header, poi chiama play_pattern.
' =============================================================================

' Includi globals, patterns, player, dac
' (assumendo che il build system li concateni nell'ordine giusto)

' --- Init DAC ---
CALL PROCinitdac

' --- Init header (hardcodato, punta a testPattern) ---
CALL read_header

' --- Stampa stato header per verifica ---
PRINT "=== Header dump ==="
PRINT "gNPat    : "; gNPat(0)
PRINT "gCurPat  : "; gCurPat(0)
PRINT ""

DIM hiB     AS BYTE
DIM loB     AS BYTE
DIM baseA   AS ADDRESS
DIM nextA   AS ADDRESS
DIM nNotes  AS INTEGER

hiB   = gPatternOffset(0)
loB   = gPatternOffset(1)
baseA = hiB * 256 + loB

hiB   = gPatternOffset(2)
loB   = gPatternOffset(3)
nextA = hiB * 256 + loB

nNotes = (nextA - baseA) / 4

PRINT "baseAddr   : "; baseA;  " ($"; HEX(baseA);  ")"
PRINT "nextAddr   : "; nextA;  " ($"; HEX(nextA);  ")"
PRINT "totalNotes : "; nNotes
PRINT ""

' --- Verifica note hardcodate in memoria ---
PRINT "=== Note in testPattern ==="
DIM i AS INTEGER
DIM tmp AS ADDRESS
FOR i = 0 TO nNotes - 1
    tmp        = baseA + i * 4
    gPatPtr(0) = tmp / 256
    gPatPtr(1) = tmp AND $FF
    CALL read_note_asm
    PRINT "nota "; i; ": DIV="; gNoteDiv(0); " IDX="; gNoteIdx(0); " SHI="; gNoteShi(0); " SLO="; gNoteSlo(0)
NEXT i
PRINT ""

' --- Play ---
PRINT "Chiamo play_pattern..."
CALL play_pattern
PRINT "Tornato! No crash."
PRINT ""
PRINT "DONE - any key"
WAIT KEY
