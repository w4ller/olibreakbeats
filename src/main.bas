' =============================================================================
' olibreakbeats - audio-test branch
' Thomson MO6 / UGBasic / Motorola 6809
'
' Player WAV nativo: legge campioni DIRETTAMENTE dal banco espanso
' senza buffer intermedio chunkBuf e senza BANK READ nel loop audio.
'
' Meccanismo bank switch MO6:
'   STA $A7E5  ->  attiva banco (numero in A)
'   LDA #7
'   STA $A7E5  ->  ripristina banco normale (7)
'
' Dopo il bank switch Y punta direttamente ai dati nel map 6809.
'
' Timing 9600 Hz @ 3.546895 MHz:
'   cicli per campione = 3546895 / 9600 = 369
'   overhead loop (LDA,STA,ADDB,LDA,ADCA,LEAY,LEAU,BNE) ~ 30 cicli
'   cicli netti per delay = 369 - 30 = 339
'   inner loop DECA(2) + BNE(3) = 5 cicli/iter -> 339/5 ~ 68 iterazioni
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
DIM gWavPtr   AS ADDRESS : GLOBAL gWavPtr    ' puntatore assoluto al primo campione
DIM gWavCount AS INTEGER : GLOBAL gWavCount  ' campioni DAC da emettere
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
'
' gWavCount = numero campioni DAC da emettere (gia calcolato tenendo
'             conto dello step, cosi Y non sfora mai oltre la fine del WAV)
' =============================================================================
PROC play_wav_direct
    ON CPU6809 BEGIN ASM
        ORCC  #$50              ; disabilita IRQ e FIRQ

        LDY   _gWavPtr          ; Y = indirizzo assoluto primo campione
        LDU   _gWavCount        ; U = campioni DAC da emettere
        CLRB                    ; B = accumulatore frazionario (reset)

        ; Attiva il banco del WAV
        LDA   _gWavBank
        STA   $A7E5

PWDL:
        LDA   ,Y                ; leggi campione dal banco
        STA   $A7CD             ; manda al DAC MO6

        ; Delay calibrato: 68 iter x 5 cicli = 340 + ~30 overhead = ~370 cicli
        ; -> 3546895 / 370 ~ 9586 Hz (errore <0.2% su 9600 Hz)
        LDA   #68
PWDL_DLY:
        DECA
        BNE   PWDL_DLY

        ; Avanza Y con step frazionario 8.8
        ; accFrac += stepLo; carry si somma a stepHi
        ADDB  _gStepLo
        LDA   _gStepHi
        ADCA  #0                ; A = stepHi + carry frazionario
        LEAY  A,Y               ; Y += A campioni reali

        ; Decrementa contatore campioni DAC
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
'
' gWavCount = campioni DAC da emettere, NON campioni reali letti.
' Con step > 1 ogni campione DAC avanza Y di piu di 1,
' quindi: dacCount = totalSamples_reali / step
'       = (totalSamples * 256) / (stepHi*256 + stepLo)
' Cio garantisce che Y non sfori mai oltre la fine del chunk WAV.
' =============================================================================
PROCEDURE play_note[chunkIdx AS INTEGER, chunkDiv AS INTEGER, stepHi AS BYTE, stepLo AS BYTE]
    DIM totalSamples AS INTEGER
    DIM step256      AS INTEGER

    totalSamples = 9600 / chunkDiv

    gWavBank = VARBANK(wave)
    gWavPtr  = VARBANKPTR(wave) + (totalSamples * chunkIdx)
    gStepHi  = stepHi
    gStepLo  = stepLo

    ' Calcola quanti campioni DAC emettere senza sforare il chunk
    ' step256 = step in virgola fissa 8.8 (es. 1.5 -> 1*256+128 = 384)
    step256   = stepHi * 256 + stepLo
    IF step256 = 0 THEN step256 = 256   ' sicurezza: step minimo = 1.0
    gWavCount = (totalSamples * 256) / step256

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
