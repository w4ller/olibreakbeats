' =============================================================================
' viewer.bas - Pattern viewer (6809 ASM wrapped in ugBASIC PROCEDURE)
' =============================================================================
'
' Uso:
'   CALL viewer_entry
'   Il viewer mostra i pattern a schermo, naviga con i tasti,
'   e ritorna al chiamante con RTS quando si preme Q.
'
' Tastiera:
'   Su/Giu  (scan $62/$6A) : scroll righe
'   Sx/Dx   (scan $61/$69) : pattern precedente/successivo
'   Q       (scan $10)     : esci dal viewer
'
' Variabili globali ugBASIC accessibili via prefisso _ in ASM:
'   _gCurPattern  : byte, pattern corrente
'   _gNPat        : byte, numero di pattern totali (primo byte array)
'   _gPatOffset   : INTEGER big-endian, offset riga 0 nel banco patFile
'   _gNRows       : byte, numero righe del pattern corrente
'   _patFile      : puntatore base banked del file pattern
'
' NOTE: gPatOffset e gNRows sono gia' dichiarate in globals.bas.
'       Qui si dichiara solo gModeViewer che e' specifica del viewer.
'
' Schermo: testo 40 colonne x 24 righe (MO6/PC128)
' Riga 0 : titolo
' Riga 2 : "PAT xx/yy"
' Riga 4 : intestazioni colonne
' Riga 5+ : dati righe
' =============================================================================

DIM gModeViewer AS BYTE : GLOBAL gModeViewer

PROCEDURE viewer_entry
    ON CPU6809 BEGIN ASM

; --- Costanti formato pattern ---
VW_PAT_HDR_BASE  EQU 1
VW_PAT_HDR_SIZE  EQU 3
VW_ROW_SIZE      EQU 8
VW_MAX_ROWS      EQU 16

VW_ROW_DIV       EQU 0
VW_ROW_IDX       EQU 1
VW_ROW_STEPHI    EQU 2
VW_ROW_STEPLO    EQU 3
VW_ROW_WAVE      EQU 4
VW_ROW_STUT      EQU 5
VW_ROW_REV       EQU 6
VW_ROW_PROB      EQU 7

; --- Tasti MO6/PC128 ---
VW_KEY_Q         EQU $10
VW_KEY_UP        EQU $62
VW_KEY_DOWN      EQU $6A
VW_KEY_LEFT      EQU $61
VW_KEY_RIGHT     EQU $69

; --- Colonne schermo ---
VW_COL_ROW       EQU 0
VW_COL_DIV       EQU 4
VW_COL_IDX       EQU 8
VW_COL_SH        EQU 12
VW_COL_SL        EQU 16
VW_COL_WV        EQU 20
VW_COL_ST        EQU 24
VW_COL_RV        EQU 28
VW_COL_PR        EQU 32
VW_YOFF_DATA     EQU 5

; --- ROM MO6 ---
VW_ROM_CLS       EQU $E806
VW_ROM_PUTCH     EQU $E803
VW_ROM_LOCATE    EQU $E809

; -------------------------------------------------------
; Stack frame locale (allocato con LEAS -10,S):
;   0,S = vwRowTop  (1 byte)
;   1,S = vwKey     (1 byte)
;   2,S = rowBuf    (8 byte)
; -------------------------------------------------------

vw_entry:
        LEAS    -10,S
        CLR     0,S
        CLR     1,S
        JSR     vw_cls
        JSR     vw_draw_header
        JSR     vw_draw_coltitles
        JSR     vw_draw_all_rows

vw_main_loop:
        JSR     vw_read_key
        JSR     vw_handle_key
        BRA     vw_main_loop

vw_exit:
        LEAS    10,S
        RTS

; --- CLS ---
vw_cls:
        JSR     [VW_ROM_CLS]
        RTS

; --- LOCATE: A=col 0-based, B=row 0-based ---
vw_locate:
        PSHS    A,B
        INCA
        INCB
        JSR     [VW_ROM_LOCATE]
        PULS    A,B
        RTS

; --- PUTCH: stampa char in A ---
vw_putch:
        JSR     [VW_ROM_PUTCH]
        RTS

; --- PUTS: X = puntatore stringa ($00 terminata) ---
vw_puts:
        PSHS    A
vw_puts_loop:
        LDA     ,X+
        BEQ     vw_puts_done
        JSR     vw_putch
        BRA     vw_puts_loop
vw_puts_done:
        PULS    A
        RTS

; --- PUTHEX: A come $XX ---
vw_puthex:
        PSHS    A
        LSRA
        LSRA
        LSRA
        LSRA
        JSR     vw_hexdig
        PULS    A
        ANDA    #$0F
        JSR     vw_hexdig
        RTS
vw_hexdig:
        ADDA    #'0'
        CMPA    #'9'+1
        BLO     vw_hexdig_out
        ADDA    #('A'-'0'-10)
vw_hexdig_out:
        JSR     vw_putch
        RTS

; --- PUTDEC: A come decimale 3 cifre ---
vw_putdec:
        PSHS    A,B
        LDB     #100
        JSR     vw_dec_digit
        LDB     #10
        JSR     vw_dec_digit
        LDB     #1
        JSR     vw_dec_digit
        PULS    A,B
        RTS
vw_dec_digit:
        PSHS    B
        CLR     ,-S
vw_dd_loop:
        CMPA    1,S
        BLO     vw_dd_emit
        SUBA    1,S
        INC     0,S
        BRA     vw_dd_loop
vw_dd_emit:
        LDB     0,S
        ADDB    #'0'
        TFR     B,A
        JSR     vw_putch
        LEAS    1,S
        PULS    B
        RTS

; --- HEADER: riga 0 titolo, riga 2 pat ---
vw_draw_header:
        LDA     #0 : LDB #0
        JSR     vw_locate
        LDX     #vw_str_title
        JSR     vw_puts
        LDA     #0 : LDB #2
        JSR     vw_locate
        LDX     #vw_str_pat
        JSR     vw_puts
        LDA     _gCurPattern
        INCA
        JSR     vw_putdec
        LDA     #'/'
        JSR     vw_putch
        LDA     _gNPat
        JSR     vw_putdec
        RTS

; --- INTESTAZIONI COLONNE: riga 4 ---
vw_draw_coltitles:
        LDA     #0 : LDB #4
        JSR     vw_locate
        LDX     #vw_str_cols
        JSR     vw_puts
        RTS

; --- DISEGNA TUTTE LE RIGHE VISIBILI ---
; Fix: ABA non esiste sul 6809. Sostituito con PSHS B / ADDA ,S+
vw_draw_all_rows:
        CLRB
vw_dar_loop:
        CMPB    #VW_MAX_ROWS
        BEQ     vw_dar_done
        LDA     0,S             ; vwRowTop
        PSHS    B               ; salva B sullo stack
        ADDA    ,S+             ; A = vwRowTop + B  (e recupera B dallo stack)
        CMPA    _gNRows
        BHS     vw_dar_done
        PSHS    A,B
        JSR     vw_fetch_row
        PULS    A,B
        PSHS    A,B
        JSR     vw_draw_one_row
        PULS    A,B
        INCB
        BRA     vw_dar_loop
vw_dar_done:
        RTS

; --- FETCH ROW: A=indice riga assoluta -> scrive in 2,S (rowBuf) ---
; Nota offset: chiamata con PSHS A,B (2 byte) => rowBuf e' a 2+2=4,S qui dentro
vw_fetch_row:
        PSHS    A,B,X,Y
        LDB     #VW_ROW_SIZE
        MUL
        ADDD    _gPatOffset
        TFR     D,X
        LEAX    _patFile,X
        LEAY    6,S             ; rowBuf: 2 orig + 4 da PSHS A,B,X,Y
        LDB     #VW_ROW_SIZE
vw_fr_loop:
        LDA     ,X+
        STA     ,Y+
        DECB
        BNE     vw_fr_loop
        PULS    A,B,X,Y
        RTS

; --- DISEGNA UNA RIGA: A=riga assoluta, B=riga visiva ---
vw_draw_one_row:
        PSHS    A,B,X
        TFR     B,A
        ADDA    #VW_YOFF_DATA
        PSHS    A               ; y corrente su stack
        LEAX    4,S             ; rowBuf: 2 orig + PSHS A,B,X(3) + PSHS A(1) = 4 da cima

        LDA     #VW_COL_ROW : LDB ,S : JSR vw_locate
        LDA     3,S             ; riga assoluta
        JSR     vw_putdec

        LDA     #VW_COL_DIV : LDB ,S : JSR vw_locate
        LDA     VW_ROW_DIV,X : JSR vw_putdec

        LDA     #VW_COL_IDX : LDB ,S : JSR vw_locate
        LDA     VW_ROW_IDX,X : JSR vw_puthex

        LDA     #VW_COL_SH : LDB ,S : JSR vw_locate
        LDA     VW_ROW_STEPHI,X : JSR vw_puthex

        LDA     #VW_COL_SL : LDB ,S : JSR vw_locate
        LDA     VW_ROW_STEPLO,X : JSR vw_puthex

        LDA     #VW_COL_WV : LDB ,S : JSR vw_locate
        LDA     VW_ROW_WAVE,X : JSR vw_puthex

        LDA     #VW_COL_ST : LDB ,S : JSR vw_locate
        LDA     VW_ROW_STUT,X : JSR vw_puthex

        LDA     #VW_COL_RV : LDB ,S : JSR vw_locate
        LDA     VW_ROW_REV,X : JSR vw_puthex

        LDA     #VW_COL_PR : LDB ,S : JSR vw_locate
        LDA     VW_ROW_PROB,X : JSR vw_putdec

        PULS    A               ; scarica y
        PULS    A,B,X
        RTS

; --- READ KEY: SWI $0C -> 1,S ---
vw_read_key:
        SWI
        FCB     $0C
        BCC     vw_rk_none
        STB     1,S
        RTS
vw_rk_none:
        CLR     1,S
        RTS

; --- HANDLE KEY ---
vw_handle_key:
        LDA     1,S
        BEQ     vw_hk_done
        CMPA    #VW_KEY_Q     : BEQ vw_exit
        CMPA    #VW_KEY_UP    : BEQ vw_hk_up
        CMPA    #VW_KEY_DOWN  : BEQ vw_hk_down
        CMPA    #VW_KEY_LEFT  : BEQ vw_hk_left
        CMPA    #VW_KEY_RIGHT : BEQ vw_hk_right
vw_hk_done:
        RTS

vw_hk_up:
        LDA     0,S : BEQ vw_hk_done
        DECA : STA 0,S
        JSR     vw_cls : JSR vw_draw_header : JSR vw_draw_coltitles : JSR vw_draw_all_rows
        RTS

vw_hk_down:
        LDA     0,S : INCA
        CMPA    _gNRows : BHS vw_hk_done
        STA     0,S
        JSR     vw_cls : JSR vw_draw_header : JSR vw_draw_coltitles : JSR vw_draw_all_rows
        RTS

vw_hk_left:
        LDA     _gCurPattern : BEQ vw_hk_done
        DECA : STA _gCurPattern
        CLR     0,S
        JSR     vw_reload_pat_hdr
        JSR     vw_cls : JSR vw_draw_header : JSR vw_draw_coltitles : JSR vw_draw_all_rows
        RTS

vw_hk_right:
        LDA     _gCurPattern : INCA
        CMPA    _gNPat : BHS vw_hk_done
        STA     _gCurPattern
        CLR     0,S
        JSR     vw_reload_pat_hdr
        JSR     vw_cls : JSR vw_draw_header : JSR vw_draw_coltitles : JSR vw_draw_all_rows
        RTS

; --- RELOAD PAT HDR: ricalcola _gPatOffset e _gNRows per _gCurPattern ---
vw_reload_pat_hdr:
        PSHS    A,B,X
        LDA     _gCurPattern
        LDB     #VW_PAT_HDR_SIZE
        MUL
        ADDD    #VW_PAT_HDR_BASE
        TFR     D,X
        LEAX    _patFile,X
        LDA     ,X   : STA _gPatOffset
        LDA     1,X  : STA _gPatOffset+1
        LDA     2,X  : STA _gNRows
        PULS    A,B,X
        RTS

; --- Stringhe ---
vw_str_title:
        FCC     "== OLIBREAKBEATS VIEWER =="
        FCB     0
vw_str_pat:
        FCC     "PAT "
        FCB     0
vw_str_cols:
        FCC     "## DV  IDX SH  SL  WV  ST  RV  PR"
        FCB     0

    END ASM ON CPU6809
END PROC
