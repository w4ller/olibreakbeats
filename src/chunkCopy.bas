' =============================================================================
' chunkCopy.bas
' Thomson MO6 / UGBasic / Motorola 6809
'
' Routine ASM per copiare un chunk del sample dal bank espanso
' al chunkBuf in RAM principale.
'
' Stessa tecnica di songCopy in olitracker_2v:
'   - scrivi bank sorgente nel Gate Array $A7E5
'   - copia count byte da src(X) a dst(Y)
'   - ripristina bank default in $A7E5
'
' Chiamata via:
'   SYS chunkCopyAddr WITH REG(A)=BANK(wave), REG(B)=defBank,
'       REG(X)=srcAddr, REG(Y)=VARPTR(chunkBuf), REG(U)=chunkSize
'       ON CPU6809
'
' Opcode disassemblato:
'   $B7 $A7 $E5        STA  $A7E5        ; seleziona bank sorgente
'   $A6 $80            LDA  ,X+          ; leggi byte da bank
'   $A7 $A0            STA  ,Y+          ; scrivi in RAM principale
'   $33 $5F            LEAU -1,U         ; decrementa contatore
'   $11 $83 $00 $00    CMPU #0
'   $26 $F4            BNE  loop (-12)   ; torna a LDA ,X+
'   $F7 $A7 $E5        STB  $A7E5        ; ripristina bank default
'   $39                RTS
' =============================================================================

DIM chunkCopy AS BYTE (18) FOR BANK READ

chunkCopy(0)  = $B7   ' STA $A7E5 (seleziona bank sorgente)
chunkCopy(1)  = $A7
chunkCopy(2)  = $E5
chunkCopy(3)  = $A6   ' LDA ,X+
chunkCopy(4)  = $80
chunkCopy(5)  = $A7   ' STA ,Y+
chunkCopy(6)  = $A0
chunkCopy(7)  = $33   ' LEAU -1,U
chunkCopy(8)  = $5F
chunkCopy(9)  = $11   ' CMPU #0
chunkCopy(10) = $83
chunkCopy(11) = $00
chunkCopy(12) = $00
chunkCopy(13) = $26   ' BNE -12 (torna a LDA ,X+)
chunkCopy(14) = $F4
chunkCopy(15) = $F7   ' STB $A7E5 (ripristina bank default)
chunkCopy(16) = $A7
chunkCopy(17) = $E5
chunkCopy(18) = $39   ' RTS

chunkCopyAddr = VARPTR(chunkCopy)
GLOBAL chunkCopyAddr

' Buffer di lavoro in RAM principale.
' Dimensionato per il chunk piu' grande possibile: SIZE(wave)/4 con div=4.
' A 8kHz mono 8bit, amen150.bin ~9600 byte -> chunk max = 2400 byte.
DIM chunkBuf AS BYTE (2400)
GLOBAL chunkBuf

' Bank di default da ripristinare dopo ogni copia (7 = RAM utente MO6).
DIM defBank AS BYTE = 7
GLOBAL defBank

PRINT "chunkCopy addr: "; HEX$(chunkCopyAddr)
