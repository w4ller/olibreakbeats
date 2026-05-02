' =============================================================================
' olibreakbeats - audio-test branch
' Thomson MO6 / UGBasic / Motorola 6809
'
' Player WAV nativo: legge campioni DIRETTAMENTE dal banco espanso
' senza buffer intermedio chunkBuf e senza BANK READ nel loop audio.
'
' Meccanismo bank switch MO6:
'   STA $A7E5  →  attiva banco (numero in A)
'   LDA #7
'   STA $A7E5  →  ripristina banco normale (7)
'
' Dopo il bank switch Y punta direttamente ai dati nel map 6809.
' =============================================================================

CLS

GLOBAL wave
wave := LOAD("assets/amen150.bin") BANKED

GLOBAL patFile
patFile := LOAD("assets/patterns.bin") BANKED

' --- Buffer RAM solo per patterns.bin (letto una volta sola) ---
DIM patBuf AS BYTE (300) FOR BANK READ : GLOBAL patBuf

' --- Interfaccia ASM player diretto ---
DIM gWavBank  AS BYTE    : GLOBAL gWavBank   ' numero banco del WAV
DIM gWavPtr   AS ADDRESS : GLOBAL gWavPtr    ' puntatore assoluto al campione corrente
DIM gWavCount AS INTEGER : GLOBAL gWavCount  ' numero campioni da suonare
DIM gStepHi   AS BYTE    : GLOBAL gStepHi    ' parte intera step (fixed 8.8)
DIM gStepLo   AS BYTE    : GLOBAL gStepLo    ' parte frazionaria step

' =============================================================================
' INIT_DAC
' =============================================================================
PROC init_dac
    ON CPU6809 BEGIN ASM
        LDA   $A7CF
        ANDA  #$FB
        STA   $A7CF
        LDB   #$3F
        STB   $A7CD
        ORA   #$04
        STA   $A7CF
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_WAV_DIRECT
' Legge e riproduce campioni DIRETTAMENTE dal banco espanso.
' Nessuna copia in RAM. Nessun BANK READ nel loop.
'
' Usa: gWavBank, gWavPtr, gWavCount, gStepHi, gStepLo
' =============================================================================
PROC play_wav_direct
    ON CPU6809 BEGIN ASM
        ORCC  #$50              ; disabilita IRQ e FIRQ

        LDY   _gWavPtr          ; Y = indirizzo assoluto primo campione
        LDU   _gWavCount        ; U = numero campioni da riprodurre
        CLRB                    ; B = accumulatore frazionario (reset)

        ; Attiva il banco del WAV
        LDA   _gWavBank
        STA   $A7E5

PWDL:
        LDA   ,Y                ; leggi campione corrente
        STA   $A7CD             ; manda al DAC MO6

        ; Timing delay (calibrato per ~9600 Hz a 3.5 MHz)
        LDA   #24
PWDL_DLY:
        DECA
        BNE   PWDL_DLY

        ; Avanza con step frazionario 8.8
        ADDB  _gStepLo          ; accFrac += stepLo
        LDA   _gStepHi
        ADCA  #0                ; A = stepHi + eventuale carry
        LEAY  A,Y               ; Y += A (parte intera + carry frac)

        ; Decrementa contatore e loop
        LEAU  -1,U
        BNE   PWDL

        ; Ripristina banco normale (7)
        LDA   #7
        STA   $A7E5

        ANDCC #$AF              ; riabilita IRQ e FIRQ
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_NOTE
' Calcola gWavPtr e gWavCount, poi chiama play_wav_direct.
' Nessun loop di blocchi: il player ASM legge tutto in un colpo solo.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM totalSamples AS INTEGER

    totalSamples = 9600 / chunkDiv

    gWavBank  = VARBANK(wave)
    gWavPtr   = VARBANKPTR(wave) + (totalSamples * chunkIdx)
    gWavCount = totalSamples
    gStepHi   = stepHi
    gStepLo   = stepLo

    CALL play_wav_direct
END PROC

' =============================================================================
' Main: legge tutto patterns.bin e suona ogni nota in loop
' =============================================================================
PRINT "audio-test"
CALL init_dac

' Copia patterns.bin in patBuf (una volta sola, fuori dal loop audio)
BANK READ VARBANK(patFile) FROM VARBANKPTR(patFile) TO VARPTR(patBuf) SIZE 300

DIM nPat     AS BYTE    : nPat    = PEEK(VARPTR(patBuf))
DIM noteAddr AS ADDRESS : noteAddr = VARPTR(patBuf)
DIM fileSize AS INTEGER : fileSize = SIZE(patFile)

PRINT "nPat     : "; nPat
PRINT "fileSize : "; fileSize

' Calcola offset primo pattern (byte 1..2 big-endian)
DIM dataStart AS INTEGER
dataStart = PEEK(noteAddr + 1) * 256 + PEEK(noteAddr + 2)
PRINT "dataStart: "; dataStart

' Numero totale di note nel file
DIM totalNotes AS INTEGER
totalNotes = (fileSize - dataStart) / 4
PRINT "totNotes : "; totalNotes

DIM n       AS INTEGER
DIM bDiv    AS BYTE
DIM bIdx    AS BYTE
DIM bStepHi AS BYTE
DIM bStepLo AS BYTE
DIM addr    AS ADDRESS

DO
    FOR n = 0 TO totalNotes - 1
        addr    = noteAddr + dataStart + n * 4
        bDiv    = PEEK(addr)
        bIdx    = PEEK(addr + 1)
        bStepHi = PEEK(addr + 2)
        bStepLo = PEEK(addr + 3)
        play_note[bIdx, bDiv, bStepHi, bStepLo]
    NEXT n
LOOP
