#!/usr/bin/env python3
"""
pat2bin.py  —  CSV pattern compiler per olibreakbeats / Thomson MO6 PC128
--------------------------------------------------------------------------
Produce un singolo file binario con header di offset + row count.

Formato CSV (con header obbligatorio, righe # = commenti):
  pattern,div,idx,semi,wave,stutter,reverse,prob
  1,4,0,0,0,0,0,255
  1,8,3,+1,255,1,0,255
  2,4,0,0,1,0,1,13

  pattern : ID numerico, qualsiasi ordine, qualsiasi valore >= 1
  div     : 1 2 4 8 16 32 64
  idx     : 0 .. div-1  oppure 255 (= RND: chunk casuale a runtime)
  semi    : -24 .. +24
  wave    : 0..4 (seleziona wave fisso) oppure 255 (= RND)
            colonna opzionale: default 0
  stutter : modalita stutter (colonna opzionale, default 0):
             0  = no stutter (1x, pitch invariato)
             1  = 2x flat    2  = 4x flat    3  = 8x flat
             4  = 2x +1semi  5  = 4x +1semi  6  = 2x +2semi  7  = 4x +2semi
             8  = 2x -1semi  9  = 4x -1semi  10 = 2x -2semi  11 = 4x -2semi
           251  = RND flat (0..3)   252 = RND pitch up+dn (4..11)
           253  = RND pitch dn (8..11)  254 = RND pitch up (4..7)
           255  = RND totale (0..11)
  reverse : direzione playback (colonna opzionale, default 0):
             0  = forward    1  = reverse    255 = RND fwd/rev
  prob    : probabilita esecuzione riga (colonna opzionale, default 255):
             0   = mai eseguita (silenziata)
             1   = ~0.4%  (1 volta ogni ~256 loop)
             13  = ~5%    (1 volta ogni ~20 loop)
             64  = ~25%
             128 = ~50%
             255 = sempre (default, backward compatible)

Formato binario output (patterns.bin):
  byte  0      : N = numero di pattern (1..255)
  byte  1..N*3 : header: WORD offset assoluto + BYTE row_count per pattern
  --- dati ---
  ogni riga    : DIV  IDX  STEP_HI  STEP_LO  WAVE_ID  STUTTER  REVERSE  PROB

  Tutti i campi colonna sono opzionali (default backward compatible).
  Limite hardware: file deve stare in un BANK (max 16384 byte).

Uso:
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --verbose
  python tools/pat2bin.py patterns/patterns.csv assets/patterns.bin --dump
"""

import csv, math, os, sys, argparse, struct

VALID_DIVS     = {1, 2, 4, 8, 16, 32, 64}
IDX_RANDOM     = 255
WAVE_RANDOM    = 255
VALID_STUTTERS = set(range(12)) | {251, 252, 253, 254, 255}
VALID_REVERSES = {0, 1, 255}

STUTTER_LABEL  = {
    0:'1x', 1:'2x', 2:'4x', 3:'8x',
    4:'2x+1↑', 5:'4x+1↑', 6:'2x+2↑', 7:'4x+2↑',
    8:'2x-1↓', 9:'4x-1↓', 10:'2x-2↓', 11:'4x-2↓',
    251:'RND-flat', 252:'RND-pitch↕', 253:'RND-pitch↓',
    254:'RND-pitch↑', 255:'RND-all',
}
REVERSE_LABEL  = {0:'fwd', 1:'rev', 255:'RND-fwd/rev'}

STUTTER_HELP = (
    "0=1x 1=2x 2=4x 3=8x "
    "4=2x+1↑ 5=4x+1↑ 6=2x+2↑ 7=4x+2↑ "
    "8=2x-1↓ 9=4x-1↓ 10=2x-2↓ 11=4x-2↓ "
    "251=RND-flat 252=RND↕ 253=RND↓ 254=RND↑ 255=RND-all"
)
REVERSE_HELP = "0=fwd 1=rev 255=RND-fwd/rev"
PROB_HELP    = "0..255  (0=mai 13=~5% 64=~25% 128=~50% 255=sempre)"

N_WAVES    = 5
ROW_BYTES  = 8
MAX_BANK   = 16 * 1024


def semi_to_step88(semi):
    raw = round((2.0 ** (semi / 12.0)) * 256)
    raw = max(1, min(0xFFFF, raw))
    return (raw >> 8) & 0xFF, raw & 0xFF


def prob_label(p):
    if p == 255: return 'always'
    if p == 0:   return 'never'
    return f'{p/255*100:.1f}%'


def compile_csv(csv_path, verbose=False):
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
                wave    = int(row.get('wave',    '0').strip() or '0')
                stutter = int(row.get('stutter', '0').strip() or '0')
                reverse = int(row.get('reverse', '0').strip() or '0')
                prob    = int(row.get('prob',  '255').strip() or '255')
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
                errors.append(f"  riga {lineno}: idx={idx} fuori range 0..{div-1}")
                continue
            if not (-24 <= semi <= 24):
                errors.append(f"  riga {lineno}: semi={semi} fuori range -24..+24")
                continue
            if wave != WAVE_RANDOM and not (0 <= wave < N_WAVES):
                errors.append(f"  riga {lineno}: wave={wave} fuori range 0..{N_WAVES-1}")
                continue
            if stutter not in VALID_STUTTERS:
                errors.append(f"  riga {lineno}: stutter={stutter} non valido\n    {STUTTER_HELP}")
                continue
            if reverse not in VALID_REVERSES:
                errors.append(f"  riga {lineno}: reverse={reverse} non valido\n    {REVERSE_HELP}")
                continue
            if not (0 <= prob <= 255):
                errors.append(f"  riga {lineno}: prob={prob} fuori range 0..255\n    {PROB_HELP}")
                continue

            shi, slo = semi_to_step88(semi)
            if verbose:
                print(f"  pat={pat_id} div={div:2d} idx={'RND' if idx==IDX_RANDOM else idx:>3} "
                      f"semi={semi:+3d} -> ${shi:02X}${slo:02X}  "
                      f"wave={'RND' if wave==WAVE_RANDOM else wave}  "
                      f"stutter={STUTTER_LABEL[stutter]}  "
                      f"reverse={REVERSE_LABEL[reverse]}  "
                      f"prob={prob_label(prob)}")
            patterns.setdefault(pat_id, []).append(
                bytes([div, idx, shi, slo, wave, stutter, reverse, prob])
            )

    if errors:
        print("ERRORI CSV:")
        for e in errors: print(e)
        sys.exit(1)

    return {k: b''.join(v) for k, v in sorted(patterns.items())}


def build_binary(patterns):
    pat_list    = list(patterns.values())
    n           = len(pat_list)
    header_size = 1 + n * 3
    offsets, cur = [], header_size
    for data in pat_list:
        offsets.append(cur)
        cur += len(data)

    header = bytes([n])
    for off, data in zip(offsets, pat_list):
        rc = len(data) // ROW_BYTES
        if rc > 255:
            print(f"ERRORE: pattern con {rc} righe, max 255."); sys.exit(1)
        header += struct.pack('>H', off) + bytes([rc])

    blob = header + b''.join(pat_list)
    if len(blob) > MAX_BANK:
        print(f"ERRORE: {len(blob)} byte supera BANK ({MAX_BANK} byte)."); sys.exit(1)
    elif len(blob) > MAX_BANK * 0.9:
        print(f"ATTENZIONE: {len(blob)} byte, margine {MAX_BANK-len(blob)} byte.")
    return blob


def dump_binary(blob):
    n = blob[0]
    print(f"\n  Header: {n} pattern")
    entries = []
    for i in range(n):
        base = 1 + i * 3
        off  = struct.unpack('>H', blob[base:base+2])[0]
        rc   = blob[base+2]
        entries.append((off, rc))
        print(f"  pattern {i+1}: offset ${off:04X}  righe={rc}")
    print()
    for i, (off, rc) in enumerate(entries):
        data = blob[off: off + rc * ROW_BYTES]
        print(f"  -- pattern {i+1} [{rc} righe] --")
        for j in range(rc):
            b = j * ROW_BYTES
            d, idx, shi, slo, wid, stt, rev, prob = data[b:b+8]
            raw  = shi*256+slo
            semi = round(12*math.log2(raw/256)) if raw else 0
            print(f"       div={d:2d} idx={'RND' if idx==IDX_RANDOM else idx:>3} "
                  f"step=${shi:02X}${slo:02X} semi={semi:+d}  "
                  f"wave={'RND' if wid==WAVE_RANDOM else wid}  "
                  f"stutter={STUTTER_LABEL.get(stt,f'?{stt}')}  "
                  f"reverse={REVERSE_LABEL.get(rev,f'?{rev}')}  "
                  f"prob={prob_label(prob)}")


def main():
    parser = argparse.ArgumentParser(
        description="CSV -> patterns.bin per olibreakbeats MO6/PC128",
        formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    parser.add_argument("csv");    parser.add_argument("output")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--dump",    "-d", action="store_true")
    args = parser.parse_args()

    print(f"\npat2bin -- {args.csv}\n")
    patterns = compile_csv(args.csv, args.verbose)
    blob     = build_binary(patterns)

    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)
    with open(args.output, 'wb') as f: f.write(blob)

    ids        = list(patterns.keys())
    hdr_size   = 1 + len(ids) * 3
    total_rows = sum(len(d)//ROW_BYTES for d in patterns.values())
    print(f"  Pattern IDs  : {ids}")
    print(f"  Header       : {hdr_size} byte")
    print(f"  Righe totali : {total_rows} x{ROW_BYTES} = {total_rows*ROW_BYTES} byte")
    print(f"  Totale       : {len(blob)} byte ({len(blob)/1024:.2f} KB)  "
          f"[BANK: {len(blob)*100//MAX_BANK}% usato]")
    print(f"  Output       : {args.output}")
    if args.dump: dump_binary(blob)


if __name__ == "__main__":
    main()
