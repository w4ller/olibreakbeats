; ============================================================
; OliBreakBeats pattern format
; ============================================================

PAT_COUNT_OFFSET      EQU 0
PAT_HEADER_BASE       EQU 1
PAT_HEADER_SIZE       EQU 3
PAT_ROW_SIZE          EQU 8

ROW_DIV               EQU 0
ROW_IDX               EQU 1
ROW_STEP_HI           EQU 2
ROW_STEP_LO           EQU 3
ROW_WAVE              EQU 4
ROW_STUTTER           EQU 5
ROW_REVERSE           EQU 6
ROW_PROB              EQU 7

IDX_RANDOM            EQU $FF
WAVE_RANDOM           EQU $FF
STUTTER_RANDOM        EQU $FF
REVERSE_RANDOM        EQU $FF
