' =============================================================================
' olibreakbeats - main.bas   v0.9  TEST
' Simula in RAM il contenuto di patterns.bin generato dal CSV:
'
'   pattern,div,idx,semi
'   1,8,255,0
'   1,16,255,0
'   1,16,255,0
'   1,16,255,0
'   2,16,0,0
'   2,16,1,0
'   2,16,2,0
'   2,16,3,0
'   2,16,4,0
'   2,16,5,0
'   2,16,6,0
'   2,16,7,0
'
' semi=0 -> stepHi=$01 stepLo=$00 (1.0x pitch)
' idx=$FF -> random slice
'
' patterns.bin layout:
'   byte 0     : N=2
'   byte 1..2  : offset pattern 1 = $0005  (5)
'   byte 3..4  : offset pattern 2 = $0015  (21)
'   byte 5..20 : pattern 1 (4 note x 4 byte)
'   byte 21..52: pattern 2 (8 note x 4 byte)
' =============================================================================

INCLUDE "src/globals.bas"
INCLUDE "src/dac.bas"
INCLUDE "src/patterns.bas"
INCLUDE "src/player.bas"

CALL init_dac

' --- Simula patterns.bin in RAM (53 byte totali) ---
DIM fakeFile(53) AS BYTE

' Header
fakeFile(0)  = 2     ' N pattern
fakeFile(1)  = $00   ' offset pat1 hi
fakeFile(2)  = $05   ' offset pat1 lo  -> byte 5
fakeFile(3)  = $00   ' offset pat2 hi
fakeFile(4)  = $15   ' offset pat2 lo  -> byte 21

' Pattern 1 - 4 note [div, idx, stepHi, stepLo]
' riga 1: div=8,  idx=255, step=1.0
fakeFile(5)  = 8   : fakeFile(6)  = $FF : fakeFile(7)  = $01 : fakeFile(8)  = $00
' riga 2: div=16, idx=255, step=1.0
fakeFile(9)  = 16  : fakeFile(10) = $FF : fakeFile(11) = $01 : fakeFile(12) = $00
' riga 3: div=16, idx=255, step=1.0
fakeFile(13) = 16  : fakeFile(14) = $FF : fakeFile(15) = $01 : fakeFile(16) = $00
' riga 4: div=16, idx=255, step=1.0
fakeFile(17) = 16  : fakeFile(18) = $FF : fakeFile(19) = $01 : fakeFile(20) = $00

' Pattern 2 - 8 note [div, idx, stepHi, stepLo]
' idx=0..7, div=16, step=1.0
fakeFile(21) = 16  : fakeFile(22) = 0  : fakeFile(23) = $01 : fakeFile(24) = $00
fakeFile(25) = 16  : fakeFile(26) = 1  : fakeFile(27) = $01 : fakeFile(28) = $00
fakeFile(29) = 16  : fakeFile(30) = 2  : fakeFile(31) = $01 : fakeFile(32) = $00
fakeFile(33) = 16  : fakeFile(34) = 3  : fakeFile(35) = $01 : fakeFile(36) = $00
fakeFile(37) = 16  : fakeFile(38) = 4  : fakeFile(39) = $01 : fakeFile(40) = $00
fakeFile(41) = 16  : fakeFile(42) = 5  : fakeFile(43) = $01 : fakeFile(44) = $00
fakeFile(45) = 16  : fakeFile(46) = 6  : fakeFile(47) = $01 : fakeFile(48) = $00
fakeFile(49) = 16  : fakeFile(50) = 7  : fakeFile(51) = $01 : fakeFile(52) = $00

' --- Costruisci gPatternOffset da fakeFile (stesso algoritmo di read_header) ---
DIM i       AS BYTE
DIM hiB     AS INTEGER
DIM loB     AS INTEGER
DIM fileOff AS INTEGER
DIM base    AS INTEGER
DIM addr    AS INTEGER
DIM slotIdx AS INTEGER

base     = VARPTR(fakeFile)
gNPat(0) = fakeFile(0)

FOR i = 1 TO gNPat(0)
    hiB     = fakeFile(1 + (i-1)*2)
    loB     = fakeFile(2 + (i-1)*2)
    fileOff = hiB * 256 + loB
    addr    = base + fileOff
    slotIdx = (i-1) * 2
    gPatternOffset(slotIdx)     = addr / 256
    gPatternOffset(slotIdx + 1) = addr AND $FF
NEXT i

' Sentinella: fine di fakeFile
addr    = base + 53
slotIdx = gNPat(0) * 2
gPatternOffset(slotIdx)     = addr / 256
gPatternOffset(slotIdx + 1) = addr AND $FF

gCurPat(0) = 1

' --- Loop: suona pattern 1 poi pattern 2 in alternanza ---
DO
    gCurPat(0) = 1
    CALL play_pattern
    gCurPat(0) = 2
    CALL play_pattern
LOOP
