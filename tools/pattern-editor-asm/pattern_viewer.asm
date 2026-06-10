; ============================================================
; pattern_viewer.asm
; Viewer skeleton for OliBreakBeats patterns
; Target: Thomson MO6 / Olivetti Prodest PC128
; CPU: 6809
; ============================================================
;
; NOTE
; Questo e' uno scheletro architetturale. Le routine video e tastiera
; sono placeholder, da collegare alle primitive reali del toolchain/ROM.
;
; Mappa memoria MO6 / PC128:
;   VRAM CPU-visible : $0000-$1FFF
;   RAM fissa        : $2000-$5FFF
;   RAM banked       : $6000-$9FFF
;
; Formato pattern (da src/globals.bas + src/patterns.bas):
;   byte 0           : N = numero pattern
;   byte 1..N*3      : header per pattern [offHi, offLo, rowCount]
;   row data (8 byte): div, idx, stepHi, stepLo, waveId, stutterMode, reverseMode, prob
;
                INCLUDE "pattern_format.inc"

; ------------------------------------------------------------
; Mappa memoria del viewer
; ------------------------------------------------------------
SCREEN_BASE      EQU $0000          ; VRAM
WORK_BASE        EQU $2100          ; variabili di stato
TEXT_BUF         EQU $2200          ; buffer testo temporaneo
PAT_BUF          EQU $4000          ; buffer pattern file (precaricato)

; ------------------------------------------------------------
; Costanti UI
; ------------------------------------------------------------
MAX_VISIBLE_ROWS EQU 16
SCREEN_COLS      EQU 40

COL_ROWNUM       EQU 0
COL_DIV          EQU 4
COL_IDX          EQU 8
COL_STEPHI       EQU 12
COL_STEPLO       EQU 16
COL_WAVE         EQU 20
COL_STUT         EQU 24
COL_REV          EQU 28
COL_PROB         EQU 32

; ------------------------------------------------------------
; Variabili di stato  (in RAM fissa)
; ------------------------------------------------------------
                ORG WORK_BASE

curPattern      RMB 1
patCount        RMB 1
curRowTop       RMB 1
curRowSel       RMB 1
curRowCount     RMB 1
curPatOffHi     RMB 1
curPatOffLo     RMB 1
keyCode         RMB 1
rowTemp         RMB PAT_ROW_SIZE
hexBuf          RMB 3

; ------------------------------------------------------------
; Entry point
; ------------------------------------------------------------
                ORG $5000
start:
                JSR init_state
                JSR load_pattern_count
                JSR load_current_pattern
main_loop:
                JSR draw_screen
                JSR read_key
                JSR handle_key
                BRA main_loop

; ------------------------------------------------------------
; init_state
; ------------------------------------------------------------
init_state:
                CLR curPattern
                CLR curRowTop
                CLR curRowSel
                RTS

; ------------------------------------------------------------
; load_pattern_count
; patCount = PAT_BUF[0]
; ------------------------------------------------------------
load_pattern_count:
                LDA PAT_BUF+PAT_COUNT_OFFSET
                STA patCount
                RTS

; ------------------------------------------------------------
; load_current_pattern
; Legge header [offHi, offLo, rowCount] per il pattern corrente
; ------------------------------------------------------------
load_current_pattern:
                LDA curPattern
                LDB #PAT_HEADER_SIZE
                MUL                     ; D = curPattern * 3
                ADDD #PAT_HEADER_BASE
                TFR D,X
                LEAX PAT_BUF,X
                LDA ,X
                STA curPatOffHi
                LDA 1,X
                STA curPatOffLo
                LDA 2,X
                STA curRowCount
                CLR curRowTop
                CLR curRowSel
                RTS

; ------------------------------------------------------------
; draw_screen
; ------------------------------------------------------------
draw_screen:
                JSR clear_screen
                JSR draw_header
                JSR draw_column_titles
                JSR draw_rows
                RTS

; ------------------------------------------------------------
; draw_header
; Riga 0: titolo
; Riga 2: "PAT xx/yy"
; ------------------------------------------------------------
draw_header:
                LDX #titleStr
                LDA #0
                LDB #0
                JSR draw_string_xy

                LDX #patStr
                LDA #0
                LDB #2
                JSR draw_string_xy

                LDA curPattern
                INCA
                LDB #4
                LDX #0
                JSR draw_byte_dec_xy

                LDA patCount
                LDB #7
                JSR draw_byte_dec_xy
                RTS

; ------------------------------------------------------------
; draw_column_titles  (riga 4)
; ------------------------------------------------------------
draw_column_titles:
                LDX #colsStr
                LDA #0
                LDB #4
                JSR draw_string_xy
                RTS

; ------------------------------------------------------------
; draw_rows
; Disegna fino a MAX_VISIBLE_ROWS righe a partire da curRowTop
; ------------------------------------------------------------
draw_rows:
                CLRB
rows_loop:
                CMPB #MAX_VISIBLE_ROWS
                BEQ rows_done

                LDA curRowTop
                ABA
                CMPA curRowCount
                BHS rows_done

                PSHS B,A
                JSR load_row             ; A = riga assoluta -> rowTemp
                PULS A,B

                PSHS B,A
                JSR draw_one_row         ; A = riga assoluta, B = riga visiva
                PULS A,B

                INCB
                BRA rows_loop
rows_done:
                RTS

; ------------------------------------------------------------
; load_row
; IN: A = indice riga assoluta
; OUT: rowTemp riempito con gli 8 byte della riga
; ------------------------------------------------------------
load_row:
                PSHS A,B,X,Y
                LDB #PAT_ROW_SIZE
                MUL                     ; D = A * 8
                ADDA curPatOffHi
                ADDB curPatOffLo
                TFR D,X
                LEAX PAT_BUF,X
                LDY #rowTemp
                LDB #PAT_ROW_SIZE
load_row_loop:
                LDA ,X+
                STA ,Y+
                DECB
                BNE load_row_loop
                PULS A,B,X,Y
                RTS

; ------------------------------------------------------------
; draw_one_row
; IN: A = riga assoluta, B = riga visiva
; Disegna una riga a schermo in posizione y = 6 + B
; ------------------------------------------------------------
draw_one_row:
                PSHS A,B,X

                ; calcola y = 6 + B
                TFR B,A
                ADDA #6
                STA hexBuf              ; riuso temporaneo come y corrente

                ; numero riga (A assoluto)
                PULS A
                PSHS A
                LDB hexBuf
                LDX #COL_ROWNUM
                JSR draw_byte_dec_xy

                ; campi singoli
                LDA rowTemp+ROW_DIV
                LDB hexBuf
                LDX #COL_DIV
                JSR draw_byte_dec_xy

                LDA rowTemp+ROW_IDX
                LDB hexBuf
                LDX #COL_IDX
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_STEP_HI
                LDB hexBuf
                LDX #COL_STEPHI
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_STEP_LO
                LDB hexBuf
                LDX #COL_STEPLO
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_WAVE
                LDB hexBuf
                LDX #COL_WAVE
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_STUTTER
                LDB hexBuf
                LDX #COL_STUT
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_REVERSE
                LDB hexBuf
                LDX #COL_REV
                JSR draw_byte_hex_xy

                LDA rowTemp+ROW_PROB
                LDB hexBuf
                LDX #COL_PROB
                JSR draw_byte_hex_xy

                PULS A,B,X
                RTS

; ------------------------------------------------------------
; handle_key
; ------------------------------------------------------------
handle_key:
                LDA keyCode
                CMPA #KEY_Q
                BEQ viewer_exit
                CMPA #KEY_LEFT
                BEQ prev_pattern
                CMPA #KEY_RIGHT
                BEQ next_pattern
                CMPA #KEY_UP
                BEQ move_up
                CMPA #KEY_DOWN
                BEQ move_down
                RTS

prev_pattern:
                LDA curPattern
                BEQ prev_done
                DECA
                STA curPattern
                JSR load_current_pattern
prev_done:      RTS

next_pattern:
                LDA curPattern
                INCA
                CMPA patCount
                BHS next_done
                STA curPattern
                JSR load_current_pattern
next_done:      RTS

move_up:
                LDA curRowTop
                BEQ mu_done
                DECA
                STA curRowTop
mu_done:        RTS

move_down:
                LDA curRowTop
                INCA
                CMPA curRowCount
                BHS md_done
                STA curRowTop
md_done:        RTS

viewer_exit:
                JMP $0000               ; placeholder - da adattare

; ------------------------------------------------------------
; Costanti tasti (da adattare al sistema)
; ------------------------------------------------------------
KEY_Q           EQU $51                 ; 'Q'
KEY_LEFT        EQU $08
KEY_RIGHT       EQU $09
KEY_UP          EQU $0B
KEY_DOWN        EQU $0A

; ------------------------------------------------------------
; PLACEHOLDER routines video/tastiera
; DA SOSTITUIRE con implementazioni reali
; ------------------------------------------------------------
clear_screen:
                ; TODO: azzerare VRAM $0000-$1FFF
                RTS

read_key:
                ; TODO: leggere un tasto e metterlo in keyCode
                CLR keyCode
                RTS

draw_string_xy:
                ; IN: X=ptr stringa (terminata da $00), A=col, B=row
                ; TODO: scrivere i caratteri a schermo
                RTS

draw_byte_dec_xy:
                ; IN: A=valore, B=row, X=col
                ; TODO: convertire A in decimale e scrivere
                RTS

draw_byte_hex_xy:
                ; IN: A=valore, B=row, X=col
                ; TODO: convertire A in hex ($XX) e scrivere
                RTS

; ------------------------------------------------------------
; Stringhe
; ------------------------------------------------------------
titleStr:
                FCC "OLIBREAKBEATS PATTERN VIEWER"
                FCB 0
patStr:
                FCC "PAT"
                FCB 0
colsStr:
                FCC "ROW DV  IDX SH  SL  WV  ST  RV  PR"
                FCB 0

                END start
