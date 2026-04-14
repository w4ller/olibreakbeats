' =============================================================================
' olibreakbeats — drum_proto.bas   v0.1  (Passo 1)
' Thomson MO6 / UGBasic / Motorola 6809
'
' ASM core player with fixed step $0100 (original pitch, no shift).
' Timing calibrated to ~8kHz via inline delay loop.
' Pattern: static breakbeat sequence from original drum.bas, cleaned up.
'
' Next step (Passo 2): make gStepHi/gStepLo live parameters per slot.
' =============================================================================

' --- Sample ---
GLOBAL wave
wave = LOAD("amen1.dat")

' --- ASM player interface (globals → accessible as _varname in ASM) ---
GLOBAL gWaveBase  AS ADDRESS    ' pointer to start of current chunk
GLOBAL gChunkSize AS INTEGER    ' number of output samples (fixed duration)
GLOBAL gStepHi    AS BYTE       ' step integer part  (8.8 fixed-pt)
GLOBAL gStepLo    AS BYTE       ' step fractional part
GLOBAL gFracAcc   AS BYTE       ' fractional accumulator (reset each chunk)

' Passo 1: fixed step = $0100 = 1.0x (original pitch)
gStepHi = $01
gStepLo = $00

' =============================================================================
' INIT_DAC
' Configure PIA port B bits 0–5 as outputs for the 6-bit DAC.
' =============================================================================
PROC init_dac
    ON CPU6809 BEGIN ASM
        LDA   $A7CF         ; read control register B
        ANDA  #$FB          ; bit 2 = 0 → DDR mode
        STA   $A7CF
        LDB   #$3F          ; bits 0–5 = outputs
        STB   $A7CD         ; write to DDRB
        ORA   #$04          ; bit 2 = 1 → data port mode
        STA   $A7CF
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_CHUNK_ASM
' Outputs exactly gChunkSize samples from gWaveBase to the DAC at ~8kHz.
' Step controlled by gStepHi / gStepLo (8.8 fixed-point).
' Duration is always gChunkSize × T_sample regardless of step value.
' =============================================================================
PROC play_chunk_asm
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase        ; [5] X = chunk start pointer
        LDY   _gChunkSize       ; [5] Y = output counter (fixed)
        CLR   _gFracAcc         ; [6] reset fractional accumulator

PCH_LOOP:
        ; --- DAC output ---
        LDA   0,X               ; [4] read sample
        STA   $A7CD             ; [5] write to DAC

        ; --- Calibrated delay ---
        ; B=17 + 1 NOP → ~124 cycles total → ~8065 Hz (closest to 8000)
        ; Remove NOP for ~122 cycles / ~8197 Hz
        ; Change to B=18 for ~127 cycles / ~7874 Hz
        LDB   #17               ; [2]
PCH_DLY:
        DECB                    ; [2]
        BNE   PCH_DLY           ; [3 taken / 2 last]
        NOP                     ; [2] fine trim: remove/add to calibrate

        ; --- Fixed-point pointer advance ---
        LDB   _gFracAcc         ; [4]
        ADDB  _gStepLo          ; [4]  frac += step_lo, carry → C
        STB   _gFracAcc         ; [4]
        LDB   _gStepHi          ; [4]
        ADCB  #0                ; [2]  int_step += carry
        ABX                     ; [3]  X += B

        ; --- Counter ---
        LEAY  -1,Y              ; [5]
        BNE   PCH_LOOP          ; [3]
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_NOTE
' High-level wrapper: selects a chunk by index and division, then calls ASM.
'
'   chunkIdx  — which slice to play (0 … chunkDiv-1)
'   chunkDiv  — how many equal slices the sample is divided into (4, 8, 16)
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER]
    gChunkSize = SIZE(wave) / chunkDiv
    gWaveBase  = VARPTR(wave) + (gChunkSize * chunkIdx)
    CALL play_chunk_asm
END PROC

' =============================================================================
' Main
' =============================================================================
PRINT "olibreakbeats v0.1 — Passo 1"
CALL init_dac

' --- Static breakbeat pattern (ported from original drum.bas) ---
' Notation: play_note[chunkIndex, totalChunks]
' e.g. play_note[1, 4] = second quarter of the sample
DO
    ' --- Bar 1 ---
    play_note[0, 16]    ' sixteenth 0   (micro-slice, thin hit)
    play_note[0, 16]
    play_note[0, 16]
    play_note[1, 4]     ' quarter 1
    play_note[2, 4]     ' quarter 2
    play_note[2, 4]

    play_note[3, 4]     ' quarter 3
    play_note[1, 4]
    play_note[2, 4]
    play_note[3, 8]     ' eighth 3
    play_note[3, 8]

    play_note[0, 4]
    play_note[1, 4]
    play_note[2, 4]
    play_note[3, 4]

    ' --- Bar 2 ---
    play_note[0, 4]
    play_note[1, 4]
    play_note[2, 4]
    play_note[2, 8]
    play_note[2, 8]

    play_note[0, 4]
    play_note[1, 4]
    play_note[2, 4]
    play_note[3, 4]

    ' --- Bar 3 ---
    play_note[0, 16]
    play_note[0, 16]
    play_note[0, 16]
    play_note[0, 16]
    play_note[1, 4]
    play_note[2, 4]
    play_note[2, 4]

    play_note[0, 4]
    play_note[1, 4]
    play_note[2, 4]
    play_note[2, 8]
    play_note[2, 8]
LOOP
