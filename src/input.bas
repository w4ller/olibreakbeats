' =============================================================================
' input.bas - Keyboard input handler (SWI $0C, MO6/PC128)
' =============================================================================
'
' Keycode map (scan codes, decimal -> hex):
'   A=14=$0E  S=22=$16  N=57=$39  P=29=$1D
'   1=$0A  2=$12  3=$1A  4=$22  5=$2A
'   6=$32  7=$33  8=$2B  9=$23
'
' gKeyPressed : raw scan code (0 = no key)
' gCurPattern : 0..gNPat(0)-1, current pattern index
' gModeAll    : 1 = play all patterns in loop
' gModeStop   : 1 = stop playback
' =============================================================================

DIM gKeyPressed AS BYTE : GLOBAL gKeyPressed
DIM gLastKey    AS BYTE : GLOBAL gLastKey
DIM gCurPattern AS BYTE : GLOBAL gCurPattern
DIM gModeAll    AS BYTE : GLOBAL gModeAll
DIM gModeStop   AS BYTE : GLOBAL gModeStop


' =============================================================================
' CHECK_KEY
' Non-blocking keyboard read via SWI $0C.
' Sets gKeyPressed = scan code (0 if no key pressed).
' =============================================================================
PROC check_key
    ON CPU6809 BEGIN ASM
        SWI
        FCB   $0C
        BCC   CK_NONE
        STB   _gKeyPressed
        BRA   CK_DONE
CK_NONE:
        CLR   _gKeyPressed
CK_DONE:
    END ASM ON CPU6809
END PROC


' =============================================================================
' HANDLE_KEY
' Call after check_key. Processes key only on press edge (not held).
' Updates gCurPattern, gModeAll, gModeStop.
' =============================================================================
PROC handle_key
    IF gKeyPressed = 0 OR gKeyPressed = gLastKey THEN
        gLastKey = gKeyPressed
        EXIT PROC
    ENDIF

    gLastKey = gKeyPressed

    SELECT CASE gKeyPressed
        CASE $0E :' A - play all
            gModeAll  = 1
            gModeStop = 0

        CASE $16 :' S - stop
            gModeStop = 1
            gModeAll  = 0

        CASE $39 :' N - next pattern
            gModeAll  = 0
            gModeStop = 0
            IF gCurPattern < gNPat(0) - 1 THEN
                gCurPattern = gCurPattern + 1
            ELSE
                gCurPattern = 0
            ENDIF

        CASE $1D :' P - previous pattern
            gModeAll  = 0
            gModeStop = 0
            IF gCurPattern > 0 THEN
                gCurPattern = gCurPattern - 1
            ELSE
                gCurPattern = gNPat(0) - 1
            ENDIF

        CASE $0A : gCurPattern = 0 : gModeAll = 0 : gModeStop = 0 :' 1
        CASE $12 : gCurPattern = 1 : gModeAll = 0 : gModeStop = 0 :' 2
        CASE $1A : gCurPattern = 2 : gModeAll = 0 : gModeStop = 0 :' 3
        CASE $22 : gCurPattern = 3 : gModeAll = 0 : gModeStop = 0 :' 4
        CASE $2A : gCurPattern = 4 : gModeAll = 0 : gModeStop = 0 :' 5
        CASE $32 : gCurPattern = 5 : gModeAll = 0 : gModeStop = 0 :' 6
        CASE $33 : gCurPattern = 6 : gModeAll = 0 : gModeStop = 0 :' 7
        CASE $2B : gCurPattern = 7 : gModeAll = 0 : gModeStop = 0 :' 8
        CASE $23 : gCurPattern = 8 : gModeAll = 0 : gModeStop = 0 :' 9
    END SELECT
END PROC
