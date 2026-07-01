' =============================================================================
' globals.bas - global variables and banked assets
' =============================================================================
'
' patterns.bin format:
'   byte 0          : N = number of patterns (1..255)
'   byte 1..N*3     : for each pattern: WORD big-endian absolute offset + BYTE row_count
'   row data        : [div, idx, stepHi, stepLo, waveId, stutterMode, 0, 0] x row_count
'                     idx=$FF         = random chunk chosen at runtime
'                     waveId=$FF      = random wave chosen at runtime (0..4)
'                     waveId=0        = default (backward compatible with old patterns)
'                     stutterMode=$00 = no stutter, 1x (default, backward compatible)
'                     stutterMode=$01 = stutter x2, flat pitch
'                     stutterMode=$02 = stutter x4, flat pitch
'                     stutterMode=$03 = stutter x8, flat pitch
'                     stutterMode=$04 = stutter x2, pitch up +1 semi/rep
'                     stutterMode=$05 = stutter x4, pitch up +1 semi/rep
'                     stutterMode=$06 = stutter x2, pitch up +2 semi/rep
'                     stutterMode=$07 = stutter x4, pitch up +2 semi/rep
'                     stutterMode=$08 = stutter x2, pitch down -1 semi/rep
'                     stutterMode=$09 = stutter x4, pitch down -1 semi/rep
'                     stutterMode=$0A = stutter x2, pitch down -2 semi/rep
'                     stutterMode=$0B = stutter x4, pitch down -2 semi/rep
'                     stutterMode=$FF = random stutter chosen at runtime (sm 0..11)
'                     byte 6..7 reserved for future use
'
' stepDelta 8.8 values used by stutterDeltaHi/Lo:
'   semi  0 -> $0100 (x1.000000)
'   semi +1 -> $010F (x1.058594, exact 2^(1/12)=1.059463)
'   semi +2 -> $011F (x1.121094, exact 2^(2/12)=1.122462)
'   semi -1 -> $00F2 (x0.945312, exact 2^(-1/12)=0.943874)
'   semi -2 -> $00E4 (x0.890625, exact 2^(-2/12)=0.890899)
' =============================================================================

' --- Banked assets ---
GLOBAL wave
wave  := LOAD("assets/amen150.bin") BANKED
GLOBAL wave2
wave2 := LOAD("assets/chords.bin") BANKED
GLOBAL wave3
wave3 := LOAD("assets/reverse.bin") BANKED
GLOBAL wave4
wave4 := LOAD("assets/future.bin") BANKED
GLOBAL wave5
wave5 := LOAD("assets/606.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- Wave lookup tables (precalculated by init_waves) ---
DIM waveAddress(5) AS WORD : GLOBAL waveAddress  :' base address of each wave
DIM wavBank(5)     AS BYTE : GLOBAL wavBank      :' bank number of each wave

' --- WAV player ASM interface (below $6000, safe from bank swap) ---
DIM gWaveBase  (2) AS BYTE FOR BANK READ : GLOBAL gWaveBase
DIM gChunkSize (2) AS BYTE FOR BANK READ : GLOBAL gChunkSize
DIM gStepHi    (1) AS BYTE FOR BANK READ : GLOBAL gStepHi
DIM gStepLo    (1) AS BYTE FOR BANK READ : GLOBAL gStepLo
DIM gFracAcc   (1) AS BYTE FOR BANK READ : GLOBAL gFracAcc
DIM gWavBank   (1) AS BYTE FOR BANK READ : GLOBAL gWavBank

' --- Total pattern count (set by init_patterns) ---
DIM gNPat      (1) AS BYTE : GLOBAL gNPat   :' number of patterns in the file

' --- Current pattern: absolute offset and row count (set by load_pattern) ---
DIM gPatOffset AS INTEGER  : GLOBAL gPatOffset  :' absolute offset into the file
DIM gNRows     AS BYTE     : GLOBAL gNRows       :' number of rows in current pattern

' --- Single row buffer (8 bytes), read one row at a time during play_pattern ---
DIM gRow (8) AS BYTE FOR BANK READ : GLOBAL gRow

' --- Stutter lookup tables (init by init_stutter) ---
' sm 0..11, $FF = RND
DIM stutterReps    (12) AS BYTE : GLOBAL stutterReps     :' repetitions per mode
DIM stutterDeltaHi (12) AS BYTE : GLOBAL stutterDeltaHi  :' 8.8 pitch delta, hi byte
DIM stutterDeltaLo (12) AS BYTE : GLOBAL stutterDeltaLo  :' 8.8 pitch delta, lo byte

' --- Pattern change flag ---
' Set to 1 by handle_key when 1-9/N/P is pressed during playback.
' Causes play_pattern to exit immediately after the current row.
' Reset to 0 by main.bas at the start of each play cycle.
DIM gPatChanged AS BYTE : GLOBAL gPatChanged


' =============================================================================
' INIT_WAVES
' Precalculates base address and bank number for each wave.
' Must be called once at startup, before any call to play_note.
' =============================================================================
PROCEDURE init_waves
    waveAddress(0) = VARBANKPTR(wave)  : wavBank(0) = VARBANK(wave)
    waveAddress(1) = VARBANKPTR(wave2) : wavBank(1) = VARBANK(wave2)
    waveAddress(2) = VARBANKPTR(wave3) : wavBank(2) = VARBANK(wave3)
    waveAddress(3) = VARBANKPTR(wave4) : wavBank(3) = VARBANK(wave4)
    waveAddress(4) = VARBANKPTR(wave5) : wavBank(4) = VARBANK(wave5)
END PROC


' =============================================================================
' INIT_STUTTER
' Populates stutterReps and stutterDelta lookup tables.
' Must be called once at startup, before any call to play_note_stutter.
'
' sm  reps  delta     effect
'  0    1   $0100     normal (no stutter)
'  1    2   $0100     stutter x2, flat
'  2    4   $0100     stutter x4, flat
'  3    8   $0100     stutter x8, flat
'  4    2   $010F     x2 pitch up +1 semi/rep
'  5    4   $010F     x4 pitch up +1 semi/rep
'  6    2   $011F     x2 pitch up +2 semi/rep
'  7    4   $011F     x4 pitch up +2 semi/rep
'  8    2   $00F2     x2 pitch down -1 semi/rep
'  9    4   $00F2     x4 pitch down -1 semi/rep
' 10    2   $00E4     x2 pitch down -2 semi/rep
' 11    4   $00E4     x4 pitch down -2 semi/rep
' =============================================================================
PROCEDURE init_stutter
    stutterReps(0)=1  : stutterReps(1)=2  : stutterReps(2)=4  : stutterReps(3)=8
    stutterReps(4)=2  : stutterReps(5)=4  : stutterReps(6)=2  : stutterReps(7)=4
    stutterReps(8)=2  : stutterReps(9)=4  : stutterReps(10)=2 : stutterReps(11)=4

    stutterDeltaHi(0)=1  : stutterDeltaHi(1)=1  : stutterDeltaHi(2)=1  : stutterDeltaHi(3)=1
    stutterDeltaHi(4)=1  : stutterDeltaHi(5)=1  : stutterDeltaHi(6)=1  : stutterDeltaHi(7)=1
    stutterDeltaHi(8)=0  : stutterDeltaHi(9)=0  : stutterDeltaHi(10)=0 : stutterDeltaHi(11)=0

    stutterDeltaLo(0)=0    : stutterDeltaLo(1)=0    : stutterDeltaLo(2)=0    : stutterDeltaLo(3)=0
    stutterDeltaLo(4)=$0F  : stutterDeltaLo(5)=$0F  : stutterDeltaLo(6)=$1F  : stutterDeltaLo(7)=$1F
    stutterDeltaLo(8)=$F2  : stutterDeltaLo(9)=$F2  : stutterDeltaLo(10)=$E4 : stutterDeltaLo(11)=$E4
END PROC


' --- Tempo control ---
DIM gPlaybackDelay (1) AS BYTE FOR BANK READ : GLOBAL gPlaybackDelay  :' delay between samples
DIM gTempoFactor   AS BYTE : GLOBAL gTempoFactor  :' tempo multiplier (128=normal @ 150BPM)
DIM gTempoIndex    AS BYTE : GLOBAL gTempoIndex   :' current index in tempo lookup (6=150BPM)

' =============================================================================
' TEMPO LOOKUP TABLES
' Calcolati per: overhead=47 cicli, CPU=996kHz, 9600 samples/bar
' Modello: total_cycles = 46 + 5*B  =>  B_esatto = (996000/rate - 46) / 5
' dove rate = 9600 * BPM / (4*60)
'
' idx  BPM   delay  stepComp  actual_BPM  errore
'   0   120    32     102      120.87     +0.87
'   1   125    31     107      123.88     -1.12  (31 piu vicino di 30)
'   2   130    29     111      130.37     +0.37
'   3   135    28     115      133.87     -1.13
'   4   140    26     119      141.48     +1.48  (26 piu vicino di 27)
'   5   145    25     124      145.61     +0.61
'   6   150    24     128      150.00     +0.00  <- esatto, base di riferimento
'   7   155    23     132      154.66     -0.34
'   8   160    22     137      159.62     -0.38
'   9   165    21     141      164.90     -0.10
'  10   170    20     145      170.55     +0.55
'  11   175    19     149      176.60     +1.60
'  12   180    18     154      183.09     +3.09  (nota: granularita bassa)
'  13   185    18     158      183.09     -1.91
'  14   190    17     162      190.08     +0.08
'  15   195    17     166      190.08     -4.92  (limite granularita)
'  16   200    16     171      200.00     +0.00  <- esatto
' =============================================================================
DIM bpmLookup     (17) AS BYTE : GLOBAL bpmLookup      :' BPM nominali
DIM bpmDelayLookup(17) AS BYTE : GLOBAL bpmDelayLookup :' delay corrispondente
DIM stepCompLookup(17) AS BYTE : GLOBAL stepCompLookup :' compensazione pitch (128=normale)


' =============================================================================
' INIT_TEMPO
' Inizializza le lookup table e imposta il tempo di default a 150 BPM.
' =============================================================================
PROCEDURE init_tempo
    ' BPM nominali
    bpmLookup(0)=120  : bpmLookup(1)=125  : bpmLookup(2)=130  : bpmLookup(3)=135
    bpmLookup(4)=140  : bpmLookup(5)=145  : bpmLookup(6)=150  : bpmLookup(7)=155
    bpmLookup(8)=160  : bpmLookup(9)=165  : bpmLookup(10)=170 : bpmLookup(11)=175
    bpmLookup(12)=180 : bpmLookup(13)=185 : bpmLookup(14)=190 : bpmLookup(15)=195
    bpmLookup(16)=200

    ' Delay calcolati: B = round((996000 / (9600*BPM/240) - 46) / 5)
    bpmDelayLookup(0)=32  :' 120 BPM
    bpmDelayLookup(1)=31  :' 125 BPM
    bpmDelayLookup(2)=29  :' 130 BPM
    bpmDelayLookup(3)=28  :' 135 BPM
    bpmDelayLookup(4)=26  :' 140 BPM
    bpmDelayLookup(5)=25  :' 145 BPM
    bpmDelayLookup(6)=24  :' 150 BPM (esatto)
    bpmDelayLookup(7)=23  :' 155 BPM
    bpmDelayLookup(8)=22  :' 160 BPM
    bpmDelayLookup(9)=21  :' 165 BPM
    bpmDelayLookup(10)=20 :' 170 BPM
    bpmDelayLookup(11)=19 :' 175 BPM
    bpmDelayLookup(12)=18 :' 180 BPM
    bpmDelayLookup(13)=18 :' 185 BPM (stesso delay di 180)
    bpmDelayLookup(14)=17 :' 190 BPM
    bpmDelayLookup(15)=17 :' 195 BPM (stesso delay di 190)
    bpmDelayLookup(16)=16 :' 200 BPM (esatto)

    ' Step compensation: (BPM * 128) / 150, normalizzato su 150 BPM
    stepCompLookup(0)=102  :' 120 BPM
    stepCompLookup(1)=107  :' 125 BPM
    stepCompLookup(2)=111  :' 130 BPM
    stepCompLookup(3)=115  :' 135 BPM
    stepCompLookup(4)=119  :' 140 BPM
    stepCompLookup(5)=124  :' 145 BPM
    stepCompLookup(6)=128  :' 150 BPM (normale)
    stepCompLookup(7)=132  :' 155 BPM
    stepCompLookup(8)=137  :' 160 BPM
    stepCompLookup(9)=141  :' 165 BPM
    stepCompLookup(10)=145 :' 170 BPM
    stepCompLookup(11)=149 :' 175 BPM
    stepCompLookup(12)=154 :' 180 BPM
    stepCompLookup(13)=158 :' 185 BPM
    stepCompLookup(14)=162 :' 190 BPM
    stepCompLookup(15)=166 :' 195 BPM
    stepCompLookup(16)=171 :' 200 BPM

    ' Default: 150 BPM (indice 6)
    gTempoIndex        = 6
    gPlaybackDelay(0)  = 24
    gTempoFactor       = 128
END PROC
