#!/usr/bin/env python3
"""
wav2mo6.py — Convertitore WAV -> DAC raw per Thomson MO6 / olibreakbeats
-----------------------------------------------------------------------
Uso:
  python wav2mo6.py input.wav output.dat [opzioni]

Opzioni:
  --bpm   FLOAT   BPM del loop sorgente      (default: 150)
  --bars  INT     Numero di bar da estrarre  (default: 1)
  --rate  INT     Sample rate target Hz      (default: 8000)
                  Valori consigliati e delay B corrispondente:
                    8000 Hz  ->  B=72   (12.5 KB per 1 bar a 150 BPM)
                    4000 Hz  ->  B=152  ( 6.2 KB per 1 bar a 150 BPM)
  --fade  INT     Fade in/out in millisecondi (default: 5)
  --preview       Salva anche una preview WAV del risultato 6-bit

Memoria PC128 (128 KB totali, ~100 KB utili):
  8000 Hz, 1 bar @ 150 BPM  ->  12.5 KB   <- default consigliato
  4000 Hz, 1 bar @ 150 BPM  ->   6.2 KB   <- minimo funzionale

Dipendenze:
  pip install numpy scipy
"""

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
from math import gcd
import argparse
import os


# ---------------------------------------------------------------------- #
# Costanti hardware MO6 / PC128                                           #
# Clock effettivo misurato empiricamente (B=72 produce ~8kHz)            #
# ---------------------------------------------------------------------- #
MO6_CLOCK_HZ  = 3_190_000
LOOP_OVERHEAD = 38
CYCLES_PER_B  = 5


def b_for_rate(rate):
    """Restituisce il valore B del delay loop ASM per il rate dato."""
    return int(round((MO6_CLOCK_HZ / rate - LOOP_OVERHEAD) / CYCLES_PER_B))


def load_wav(path):
    """Legge WAV, downmix mono, normalizza a float64 [-1, 1]."""
    rate, data = wavfile.read(path)
    if data.ndim == 2:
        data = data.mean(axis=1)
    if data.dtype == np.int16:
        data = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.uint8:
        data = (data.astype(np.float64) - 128.0) / 128.0
    else:
        data = data.astype(np.float64)
        peak = np.max(np.abs(data))
        if peak > 0:
            data /= peak
    return rate, data


def do_resample(data, rate_in, rate_out):
    """Resample con filtro polifasico (alta qualita', no aliasing)."""
    if rate_in == rate_out:
        return data
    g = gcd(int(rate_in), int(rate_out))
    return resample_poly(data, rate_out // g, rate_in // g)


def trim_to_bars(data, rate, bpm, bars):
    """Ritaglia o ripete il sample per coprire esattamente N bar al BPM dato."""
    seconds = (60.0 / bpm) * 4 * bars
    n = int(round(seconds * rate))
    if len(data) >= n:
        return data[:n], n
    reps = int(np.ceil(n / len(data)))
    return np.tile(data, reps)[:n], n


def apply_fade(data, rate, fade_ms):
    """Fade in e fade out lineari per evitare click ai bordi del loop."""
    if fade_ms <= 0:
        return data
    fade_samples = min(int(rate * fade_ms / 1000), len(data) // 4)
    if fade_samples == 0:
        return data
    ramp = np.linspace(0.0, 1.0, fade_samples)
    data = data.copy()
    data[:fade_samples]  *= ramp
    data[-fade_samples:] *= ramp[::-1]
    return data


def to_6bit(data_float):
    """
    float [-1, 1]  ->  uint8 [0, 255]  ->  >> 2  ->  uint8 [0, 63]
    I 6 bit utili stanno in posizione 0-5: formato atteso da STA $A7CD.
    """
    peak = np.max(np.abs(data_float))
    if peak > 0:
        data_float = data_float / peak
    u8 = ((data_float + 1.0) * 127.5).clip(0, 255).astype(np.uint8)
    return (u8 >> 2).astype(np.uint8)


def save_preview_wav(data_6bit, rate, output_dat_path):
    """Preview WAV ascoltabile del risultato 6-bit (upscala [0,63]->[0,252])."""
    preview_path = os.path.splitext(output_dat_path)[0] + '_preview.wav'
    preview_u8 = (data_6bit.astype(np.uint16) * 4).clip(0, 255).astype(np.uint8)
    wavfile.write(preview_path, rate, preview_u8)
    print(f"  Preview WAV  : {os.path.basename(preview_path)}")


def print_report(input_path, output_path, rate_in, target_rate,
                 bpm, bars, n, fade_ms):
    b = b_for_rate(target_rate)
    print()
    print("=" * 60)
    print("  wav2mo6 — Thomson MO6 / PC128 sample converter")
    print("=" * 60)
    print(f"  Input        : {os.path.basename(input_path)}")
    print(f"  Input rate   : {rate_in} Hz")
    print(f"  Target rate  : {target_rate} Hz  ->  usa B={b} nel player ASM")
    print(f"  BPM / Bar    : {bpm} BPM, {bars} bar")
    print(f"  Fade in/out  : {fade_ms} ms")
    print(f"  Campioni     : {n}")
    print(f"  Bytes totali : {n}  ({n/1024:.1f} KB)")
    print(f"  Durata       : {n/target_rate:.4f} s")
    print(f"  Output       : {os.path.basename(output_path)}")
    print()
    print("  Chunk sizes per pattern slicing:")
    for nd in [4, 8, 16, 32]:
        cs = n // nd
        ms = (cs / target_rate) * 1000
        print(f"    N={nd:2d}  ->  {cs:5d} bytes/chunk  ({ms:.1f} ms)")
    print()
    print(f"  Memoria PC128 (128 KB totali, ~100 KB utili):")
    print(f"    Sample       : {n/1024:.1f} KB")
    print(f"    Disponibile  : {100 - n/1024:.1f} KB per codice + stack")
    print()
    print("  In ugBASIC:")
    print(f'    wave = LOAD("{os.path.basename(output_path)}")')
    print(f"    ' Aggiorna il delay nel player: LDB #{b}")
    print("=" * 60)


def convert(input_wav, output_dat, bpm=150, bars=1,
            target_rate=8000, fade_ms=5, preview=False):
    rate_in, data = load_wav(input_wav)
    data = do_resample(data, rate_in, target_rate)
    data, n = trim_to_bars(data, target_rate, bpm, bars)
    data = apply_fade(data, target_rate, fade_ms)
    out = to_6bit(data)
    out.tofile(output_dat)
    print_report(input_wav, output_dat, rate_in, target_rate,
                 bpm, bars, n, fade_ms)
    if preview:
        save_preview_wav(out, target_rate, output_dat)
    return out


def main():
    parser = argparse.ArgumentParser(
        description="Converte WAV in formato DAC raw 6-bit per Thomson MO6 / PC128",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("input",              help="File WAV sorgente")
    parser.add_argument("output",             help="File .dat di output (in assets/)")
    parser.add_argument("--bpm",  type=float, default=150,
                        help="BPM del loop (default: 150)")
    parser.add_argument("--bars", type=int,   default=1,
                        help="Numero di bar da estrarre (default: 1)")
    parser.add_argument("--rate", type=int,   default=8000,
                        help="Sample rate target Hz (default: 8000)")
    parser.add_argument("--fade", type=int,   default=5,
                        help="Fade in/out in ms (default: 5)")
    parser.add_argument("--preview", action="store_true",
                        help="Salva anche una preview WAV del risultato 6-bit")
    args = parser.parse_args()
    convert(args.input, args.output,
            args.bpm, args.bars, args.rate, args.fade, args.preview)


if __name__ == "__main__":
    main()
