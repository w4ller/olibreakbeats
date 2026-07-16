' =============================================================================
' PLAY_CHUNK_ASM
' Outputs gChunkSize samples from gWaveBase at 8.8 fixed-point step.
' Legge dalla fine del BANK corrente (settato da gWavBank).
' Timing loop: ~125us per sample = ~8kHz.
' Bank is restored to 7 after playback.
' =============================================================================
PROC play_chunk_asm
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc

        LDA   _gWavBank
        STA   $A7E5

PCH_LOOP:
        LDA   0,X
        STA   $A7CD

        LDB   _gPlaybackDelay 
PCH_DLY:
        DECB
        BNE   PCH_DLY

        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDB   _gStepHi
        ADCB  #0
        ABX

        LEAY  -1,Y
        BNE   PCH_LOOP

        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC

' =============================================================================
' PLAY_CHUNK_ASM_REV
' Come play_chunk_asm ma legge il chunk al contrario.
' gWaveBase deve puntare all ULTIMO byte del chunk (non al primo).
' Step e' POSITIVO (non negato): la routine lo sottrae tramite NEGA+LEAU.
'
' Tecnica decremento:
'   ABX usa ACCB come UNSIGNED -> non puo fare decremento.
'   LEAU A,U usa A come SIGNED 8-bit -> NEGA + LEAU A,U decrementa.
'   Es: step=1.0 -> A=1 -> NEGA -> A=$FF (-1) -> LEAU A,U -> U-=1. Corretto.
'
' Registro U usato come puntatore (X resta libero per ugBasic).
' Overhead vs play_chunk_asm: +2 cicli/sample (NEGA) = ~5% su 8kHz.
' =============================================================================
PROC play_chunk_asm_rev
    ON CPU6809 BEGIN ASM
        LDX   _gWaveBase
        LDY   _gChunkSize
        CLR   _gFracAcc

        LDA   _gWavBank
        STA   $A7E5

PCR_LOOP:
        LDA   0,X
        STA   $A7CD

        LDB   _gPlaybackDelay
PCR_DLY:
        DECB
        BNE   PCR_DLY

        LDB   _gFracAcc
        ADDB  _gStepLo
        STB   _gFracAcc
        LDA   _gStepHi
        ADCA  #0
        NEGA
        LEAX  A,X

        LEAY  -1,Y
        BNE   PCR_LOOP


        LDA   #7
        STA   $A7E5
    END ASM ON CPU6809
END PROC