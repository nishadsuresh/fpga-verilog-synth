"""Phase 2 acceptance check: FFT-measures the dominant frequency of each
rendered note and verifies it's within 5 cents of the target, using
parabolic interpolation around the FFT peak bin for sub-bin-resolution
frequency estimation (needed since a single FFT bin at 0.5s/48kHz is ~2Hz
wide -- far coarser than the 5-cent tolerance at low notes)."""

import sys
import wave
import numpy as np

SAMPLE_RATE_HZ = 48_000


def measure_frequency(wav_path: str) -> float:
    with wave.open(wav_path, "rb") as wf:
        n = wf.getnframes()
        raw = wf.readframes(n)
    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float64)

    windowed = samples * np.hanning(len(samples))
    spectrum = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(len(windowed), d=1 / SAMPLE_RATE_HZ)

    peak_bin = int(np.argmax(spectrum))
    if peak_bin == 0 or peak_bin == len(spectrum) - 1:
        return freqs[peak_bin]

    # parabolic interpolation (quadratic fit through peak and its two neighbors)
    y0, y1, y2 = spectrum[peak_bin - 1], spectrum[peak_bin], spectrum[peak_bin + 1]
    denom = y0 - 2 * y1 + y2
    delta = 0.5 * (y0 - y2) / denom if denom != 0 else 0.0
    bin_width = freqs[1] - freqs[0]
    return freqs[peak_bin] + delta * bin_width


def cents_error(measured_hz: float, target_hz: float) -> float:
    return 1200 * np.log2(measured_hz / target_hz)


if __name__ == "__main__":
    notes = [("A2", "samples_a2.wav", 110.0), ("A4", "samples_a4.wav", 440.0), ("A6", "samples_a6.wav", 1760.0)]
    all_pass = True
    for name, wav_file, target in notes:
        measured = measure_frequency(wav_file)
        err = cents_error(measured, target)
        status = "PASS" if abs(err) < 5.0 else "FAIL"
        if abs(err) >= 5.0:
            all_pass = False
        print(f"  {name}: target={target}Hz measured={measured:.4f}Hz error={err:+.4f} cents [{status}]")

    print(f"\nPhase 2 acceptance: {'PASS' if all_pass else 'FAIL'} (need |error| < 5 cents for all three notes)")
    sys.exit(0 if all_pass else 1)
