#!/usr/bin/env python3
"""
pat2bin.py  —  CSV pattern compiler per olibreakbeats / Thomson MO6 PC128
--------------------------------------------------------------------------
Produce un singolo file binario con header di offset.

Formato CSV (con header obbligatorio, righe # = commenti):
  pattern,div,idx,semi
  1,4,0,0
  1,8,3,+1

  pattern : ID numerico, qualsiasi ordine, qualsiasi valore >= 1
  div     : 1 2 4 8 16 32 64
  idx     : 0 .. div-1
  semi    : -24 .. +24

Formato binario output (patterns.bin):
  byte  0       : N = numero di pattern nel file (1..255)
  byte  1..2    : WORD big-endian, offset assoluto pattern 1
  byte  3..4    : WORD big-endian, offset assoluto pattern 2
  ...
  byte  N*2-1   : ultimo offset
  --- dati ---
  ogni pattern  : note da 4 byte ciascuna, NESSUN terminatore
  ogni nota     : DIV  IDX  STEP_HI  STEP_LO

  Offset e' assoluto dall'inizio del file.
  Header size = 1 + N*2 byte.
  Numero note pattern i = (offset(i+1) - offset(i)) / 4
  Numero note ultimo    = (file_size   - offset(N)) / 4

Uso:
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --verbose
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --dump
"""

import csv, math, os, sys, argparse, struct

VALID_DIVS = {1, 2, 4, 8, 16, 32, 64}


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
                pat_id = int(row['pattern'].strip())
                div    = int(row['div'].strip())
                idx    = int(row['idx'].strip())
                semi   = int(row['semi'].strip())
            except (ValueError, KeyError) as e:
                errors.append(f"  riga {lineno}: {e}")
                continue

            if pat_id < 1:
                errors.append(f"  riga {lineno}: pattern={pat_id} deve essere >= 1")
                continue
            if div not in VALID_DIVS:
                errors.append(f"  riga {lineno}: div={div} non valido {sorted(VALID_DIVS)}")
                continue
            if not (0 <= idx < div):
                errors.append(f"  riga {lineno}: idx={idx} fuori range 0..{div-1} per div={div}")
                continue
            if not (-24 <= semi <= 24):
                errors.append(f"  riga {lineno}: semi={semi} fuori range -24..+24")
                continue

            shi, slo = semi_to_step88(semi)
            if verbose:
                print(f"  pat={pat_id} div={div:2d} idx={idx:2d} semi={semi:+3d} "
                      f"-> ${shi:02X}${slo:02X} ({2**(semi/12):.4f}x)")
            patterns.setdefault(pat_id, []).append(bytes([div, idx, shi, slo]))

    if errors:
        print("ERRORI CSV:")
        for e in errors:
            print(e)
        sys.exit(1)

    # Nessun terminatore: solo le note grezze
    return {k: b''.join(v) for k, v in sorted(patterns.items())}


def build_binary(patterns: dict) -> bytes:
    """
    Assembla header + dati in un unico blob binario.
      byte 0      : N (numero pattern)
      byte 1..2*N : N x WORD big-endian offset assoluto
      poi dati pattern consecutivi, nessun terminatore
    """
    pat_list    = list(patterns.values())   # gia' ordinati per id
    n           = len(pat_list)
    header_size = 1 + n * 2                # 1 byte N + N * 2 byte offset

    offsets = []
    cur = header_size
    for data in pat_list:
        offsets.append(cur)
        cur += len(data)

    if cur > 65535:
        print(f"ATTENZIONE: file totale {cur} byte supera 65535 — offset WORD overflow.")

    header = bytes([n])
    for off in offsets:
        header += struct.pack('>H', off)    # big-endian WORD

    return header + b''.join(pat_list)


def dump_binary(blob: bytes):
    """Stampa una decodifica leggibile del file binario."""
    file_size = len(blob)
    n = blob[0]
    header_size = 1 + n * 2
    print(f"\n  Header: {n} pattern, {header_size} byte")

    offsets = []
    for i in range(n):
        off = struct.unpack('>H', blob[1 + i*2 : 3 + i*2])[0]
        offsets.append(off)

    for i, off in enumerate(offsets):
        end        = offsets[i+1] if i+1 < n else file_size
        note_count = (end - off) // 4
        print(f"  pattern {i+1}: offset ${off:04X}  note={note_count}  byte={end-off}")

    print()
    for i, off in enumerate(offsets):
        end  = offsets[i+1] if i+1 < n else file_size
        data = blob[off:end]
        note_count = len(data) // 4
        print(f"  -- pattern {i+1} [{note_count} note] --")
        for j in range(note_count):
            d, idx, shi, slo = data[j*4], data[j*4+1], data[j*4+2], data[j*4+3]
            raw  = shi * 256 + slo
            semi = round(12 * math.log2(raw / 256)) if raw > 0 else 0
            print(f"       div={d:2d}  idx={idx:2d}  step=${shi:02X}${slo:02X}  semi={semi:+d}")


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
    header_size = 1 + len(ids) * 2
    print(f"  Pattern IDs  : {ids}")
    print(f"  Header       : {header_size} byte  (1 + {len(ids)}x2)")
    print(f"  Dati         : {len(blob) - header_size} byte")
    print(f"  Totale       : {len(blob)} byte  ({len(blob)/1024:.2f} KB)")
    print(f"  Output       : {args.output}")

    if args.dump:
        dump_binary(blob)


if __name__ == "__main__":
    main()
