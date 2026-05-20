#!/usr/bin/env python3
"""
pat2bin.py  —  CSV pattern compiler per olibreakbeats / Thomson MO6 PC128
--------------------------------------------------------------------------
Produce un singolo file binario con header di offset + row count.

Formato CSV (con header obbligatorio, righe # = commenti):
  pattern,div,idx,semi,wave,stutter
  1,4,0,0,0,0
  1,8,3,+1,255,1
  2,4,0,0,1,255

  pattern : ID numerico, qualsiasi ordine, qualsiasi valore >= 1
  div     : 1 2 4 8 16 32 64
  idx     : 0 .. div-1  oppure 255 (= RND: chunk casuale a runtime)
  semi    : -24 .. +24
  wave    : 0..4 (seleziona wave fisso) oppure 255 (= RND: wave casuale a runtime)
            colonna opzionale: default 0 (backward compatible con CSV senza wave)
  stutter : modalita stutter (colonna opzionale, default 0):
             0  = no stutter (1x, pitch invariato)
             1  = 2x, pitch invariato
             2  = 4x, pitch invariato
             3  = 8x, pitch invariato
             4  = 2x, pitch up   +1 semitono/rep
             5  = 4x, pitch up   +1 semitono/rep
             6  = 2x, pitch up   +2 semitoni/rep
             7  = 4x, pitch up   +2 semitoni/rep
             8  = 2x, pitch down -1 semitono/rep
             9  = 4x, pitch down -1 semitono/rep
            10  = 2x, pitch down -2 semitoni/rep
            11  = 4x, pitch down -2 semitoni/rep
           251  = RND flat       (sm 0..3,  no pitch change)
           252  = RND pitch up+dn (sm 4..11, up o down, no flat)
           253  = RND pitch down  (sm 8..11)
           254  = RND pitch up    (sm 4..7)
           255  = RND totale      (sm 0..11)

Formato binario output (patterns.bin):
  byte  0         : N = numero di pattern nel file (1..255)
  byte  1..3      : 3 byte per pattern 1: WORD big-endian offset assoluto + BYTE row_count
  byte  4..6      : 3 byte per pattern 2: WORD big-endian offset assoluto + BYTE row_count
  ...
  byte  N*3-1     : ultimo gruppo
  --- dati ---
  ogni pattern    : righe da 8 byte ciascuna, NESSUN terminatore
  ogni riga       : DIV  IDX  STEP_HI  STEP_LO  WAVE_ID  STUTTER  0x00  0x00
                    (ultimi 2 byte riservati per effetti futuri)

  IDX         = 255 ($FF) = chunk casuale scelto a runtime tra 0..DIV-1.
  WAVE_ID     = 255 ($FF) = wave casuale scelto a runtime tra 0..4.
  WAVE_ID     = 0         = default (backward compatible con vecchi pattern).
  STUTTER     = 0         = nessuno stutter (backward compatible).
  STUTTER     = 255 ($FF) = stutter casuale scelto a runtime (sm 0..11).

  Offset e' assoluto dall'inizio del file.
  Header size = 1 + N*3 byte.
  Numero righe pattern i = row_count letto direttamente dall'header (no calcoli).

  Limite hardware: il file deve stare in un singolo BANK (max 16 KB = 16384 byte).

Uso:
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --verbose
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --dump
"""

import csv, math, os, sys, argparse, struct

VALID_DIVS      = {1, 2, 4, 8, 16, 32, 64}
IDX_RANDOM      = 255        # valore speciale: chunk casuale a runtime
WAVE_RANDOM     = 255        # valore speciale: wave casuale a runtime

# Valori stutter validi: 0..11 diretti + $FB..$FF speciali
VALID_STUTTERS  = set(range(12)) | {251, 252, 253, 254, 255}

STUTTER_LABEL   = {
    0:  '1x',
    1:  '2x',
    2:  '4x',
    3:  '8x',
    4:  '2x+1semi↑',
    5:  '4x+1semi↑',
    6:  '2x+2semi↑',
    7:  '4x+2semi↑',
    8:  '2x-1semi↓',
    9:  '4x-1semi↓',
    10: '2x-2semi↓',
    11: '4x-2semi↓',
    251: 'RND-flat',
    252: 'RND-pitch↕',
    253: 'RND-pitch↓',
    254: 'RND-pitch↑',
    255: 'RND-all',
}

STUTTER_HELP = (
    "0=1x  1=2x  2=4x  3=8x  "
    "4=2x+1semi↑  5=4x+1semi↑  6=2x+2semi↑  7=4x+2semi↑  "
    "8=2x-1semi↓  9=4x-1semi↓  10=2x-2semi↓  11=4x-2semi↓  "
    "251=RND-flat  252=RND-pitch↕  253=RND-pitch↓  254=RND-pitch↑  255=RND-all"
)

N_WAVES         = 5          # wave0..wave4
ROW_BYTES       = 8          # byte per riga: 6 dati + 2 riservati
MAX_BANK        = 16 * 1024  # 16384 byte — limite BANK hardware


def semi_to_step88(semi: int) -> tuple:
    raw = round((2.0 ** (semi / 12.0)) * 256)
    raw = max(1, min(0xFFFF, raw))
    return (raw >> 8) & 0xFF, raw & 0xFF


def compile_csv(csv_path: str, verbose: bool = False) -> dict:
    """Legge il CSV e restituisce dict {pattern_id (int): bytes} senza terminatore."""
    patterns = {}
    errors   = []

    with open(csv_path, newline='', encoding='utf-8') as f:
        clean = (l for l in f if not l.strip().startswith('#') and l.strip())
        reader = csv.DictReader(clean)
        for lineno, row in enumerate(reader, start=2):
            if not row.get('pattern', '').strip():
                continue
            try:
                pat_id  = int(row['pattern'].strip())
                div     = int(row['div'].strip())
                idx     = int(row['idx'].strip())
                semi    = int(row['semi'].strip())
                wave_raw    = row.get('wave',    '0').strip() or '0'
                stutter_raw = row.get('stutter', '0').strip() or '0'
                wave    = int(wave_raw)
                stutter = int(stutter_raw)
            except (ValueError, KeyError) as e:
                errors.append(f"  riga {lineno}: {e}")
                continue

            if pat_id < 1:
                errors.append(f"  riga {lineno}: pattern={pat_id} deve essere >= 1")
                continue
            if div not in VALID_DIVS:
                errors.append(f"  riga {lineno}: div={div} non valido {sorted(VALID_DIVS)}")
                continue
            if idx != IDX_RANDOM and not (0 <= idx < div):
                errors.append(f"  riga {lineno}: idx={idx} fuori range 0..{div-1} per div={div}")
                continue
            if not (-24 <= semi <= 24):
                errors.append(f"  riga {lineno}: semi={semi} fuori range -24..+24")
                continue
            if wave != WAVE_RANDOM and not (0 <= wave < N_WAVES):
                errors.append(f"  riga {lineno}: wave={wave} fuori range 0..{N_WAVES-1} (o 255=RND)")
                continue
            if stutter not in VALID_STUTTERS:
                errors.append(
                    f"  riga {lineno}: stutter={stutter} non valido\n"
                    f"    valori: {STUTTER_HELP}"
                )
                continue

            shi, slo = semi_to_step88(semi)
            idx_str  = "RND" if idx     == IDX_RANDOM  else str(idx)
            wav_str  = "RND" if wave    == WAVE_RANDOM  else str(wave)
            stt_str  = STUTTER_LABEL[stutter]
            if verbose:
                print(f"  pat={pat_id} div={div:2d} idx={idx_str:>3} semi={semi:+3d} "
                      f"-> ${shi:02X}${slo:02X} ({2**(semi/12):.4f}x)  wave={wav_str}  stutter={stt_str}")
            patterns.setdefault(pat_id, []).append(bytes([div, idx, shi, slo, wave, stutter, 0, 0]))

    if errors:
        print("ERRORI CSV:")
        for e in errors:
            print(e)
        sys.exit(1)

    return {k: b''.join(v) for k, v in sorted(patterns.items())}


def build_binary(patterns: dict) -> bytes:
    pat_list    = list(patterns.values())
    n           = len(pat_list)
    header_size = 1 + n * 3

    offsets = []
    cur = header_size
    for data in pat_list:
        offsets.append(cur)
        cur += len(data)

    header = bytes([n])
    for off, data in zip(offsets, pat_list):
        row_count = len(data) // ROW_BYTES
        if row_count > 255:
            print(f"ERRORE: un pattern ha {row_count} righe, massimo consentito 255.")
            sys.exit(1)
        header += struct.pack('>H', off) + bytes([row_count])

    blob = header + b''.join(pat_list)

    if len(blob) > MAX_BANK:
        print(f"ERRORE: file {len(blob)} byte supera il limite BANK di {MAX_BANK} byte "
              f"({len(blob) - MAX_BANK} byte in eccesso). Riduci pattern o righe.")
        sys.exit(1)
    elif len(blob) > MAX_BANK * 0.9:
        print(f"ATTENZIONE: file {len(blob)} byte — vicino al limite BANK "
              f"({MAX_BANK} byte). Margine residuo: {MAX_BANK - len(blob)} byte.")

    return blob


def dump_binary(blob: bytes):
    n = blob[0]
    header_size = 1 + n * 3
    print(f"\n  Header: {n} pattern, {header_size} byte")

    entries = []
    for i in range(n):
        base      = 1 + i * 3
        off       = struct.unpack('>H', blob[base:base+2])[0]
        row_count = blob[base+2]
        entries.append((off, row_count))
        print(f"  pattern {i+1}: offset ${off:04X}  righe={row_count}  byte={row_count * ROW_BYTES}")

    print()
    for i, (off, row_count) in enumerate(entries):
        data = blob[off : off + row_count * ROW_BYTES]
        print(f"  -- pattern {i+1} [{row_count} righe] --")
        for j in range(row_count):
            base_r  = j * ROW_BYTES
            d, idx, shi, slo, wave_id, stutter = (
                data[base_r], data[base_r+1], data[base_r+2],
                data[base_r+3], data[base_r+4], data[base_r+5]
            )
            raw      = shi * 256 + slo
            semi     = round(12 * math.log2(raw / 256)) if raw > 0 else 0
            idx_str  = "RND" if idx     == IDX_RANDOM   else str(idx)
            wave_str = "RND" if wave_id == WAVE_RANDOM   else str(wave_id)
            stt_str  = STUTTER_LABEL.get(stutter, f"?{stutter}")
            print(f"       div={d:2d}  idx={idx_str:>3}  step=${shi:02X}${slo:02X}  semi={semi:+d}  wave={wave_str}  stutter={stt_str}")


def main():
    parser = argparse.ArgumentParser(
        description="CSV -> patterns.bin per olibreakbeats MO6/PC128",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("csv",    help="File CSV sorgente")
    parser.add_argument("output", help="File .bin di output")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--dump",    "-d", action="store_true",
                        help="Stampa decodifica del binario prodotto")
    args = parser.parse_args()

    print(f"\npat2bin -- {args.csv}\n")
    patterns = compile_csv(args.csv, args.verbose)
    blob     = build_binary(patterns)

    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)
    with open(args.output, 'wb') as f:
        f.write(blob)

    ids         = list(patterns.keys())
    header_size = 1 + len(ids) * 3
    total_rows  = sum(len(d) // ROW_BYTES for d in patterns.values())
    print(f"  Pattern IDs  : {ids}")
    print(f"  Header       : {header_size} byte  (1 + {len(ids)}x3)")
    print(f"  Righe totali : {total_rows}  x{ROW_BYTES} byte = {total_rows * ROW_BYTES} byte dati")
    print(f"  Totale       : {len(blob)} byte  ({len(blob)/1024:.2f} KB)  "
          f"[BANK: {len(blob)*100//MAX_BANK}% usato]")
    print(f"  Output       : {args.output}")

    if args.dump:
        dump_binary(blob)


if __name__ == "__main__":
    main()
