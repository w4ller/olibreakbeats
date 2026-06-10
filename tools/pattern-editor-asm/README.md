# Pattern editor ASM skeleton

Questo tool e' uno scheletro iniziale per un viewer/editor leggero in assembly 6809 per Thomson MO6 / Olivetti Prodest PC128.

## Obiettivo

Mostrare i pattern di OliBreakBeats a motore fermo, con una UI minimale a griglia, pensata per restare molto leggera.

## Assunzioni usate

- Il formato pattern e' quello gia' usato dal progetto:
  - byte 0 = numero pattern
  - tabella header da 3 byte per pattern: offset assoluto big-endian + row count
  - ogni riga = 8 byte: `div, idx, stepHi, stepLo, waveId, stutterMode, reverseMode, prob`
- Sulla macchina MO6 / PC128 la VRAM CPU-visible occupa `$0000-$1FFF`, la RAM fissa `$2000-$5FFF`, e la finestra banked `$6000-$9FFF`.

## File

- `pattern_viewer.asm` : viewer-only, prima base di lavoro
- `pattern_format.inc` : costanti del formato pattern

## Stato

Questo codice non pretende ancora di assemblare o girare cosi' com'e': e' un punto di partenza strutturato per definire:

- layout schermo
- variabili di stato
- parsing header pattern
- navigazione pattern/righe
- rendering tabellare

## UI prevista

- intestazione con numero pattern corrente
- tabella con colonne: `DV IDX SH SL WV ST RV PR`
- cursore riga
- tasti previsti:
  - frecce su/giu': scroll righe
  - frecce sx/dx: pattern precedente/successivo
  - `Q`: uscita
  - `E`: futuro edit mode

## Passi successivi

1. agganciare le routine video/keyboard reali dell'ambiente scelto
2. implementare `draw_char`, `draw_string`, `clear_screen`
3. leggere il file pattern da RAM o da buffer precaricato
4. aggiungere edit dei campi byte
