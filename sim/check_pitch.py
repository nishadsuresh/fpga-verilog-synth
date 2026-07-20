"""Phase 2 acceptance check: FFT-measures the dominant frequency of each
rendered note and verifies it's within 5 cents of the target, using
parabolic interpolation around the FFT peak bin for sub-bin-resolution
frequency estimation (needed since a single FFT bin at 0.5s/48kHz is ~2Hz
wide -- far coarser than the 5-cent tolerance at low notes)."""

import sys
import wave
import numpy as np

from fft_utils import dominant_freq

SAMPLE_RATE_HZ = 48_000


def measure_frequency(wav_path: str) -> float:
    with wave.open(wav_path, "rb") as wf:
        assert wf.getnchannels() == 1 and wf.getsampwidth() == 2, \
            f"{wav_path}: expected mono 16-bit PCM (as render_wav.py always produces), got " \
            f"{wf.getnchannels()}ch/{wf.getsampwidth()*8}bit"
        n = wf.getnframes()
        raw = wf.readframes(n)
    samples = np.frombuffer(raw, dtype=np.int16)
    return dominant_freq(samples, SAMPLE_RATE_HZ)


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
