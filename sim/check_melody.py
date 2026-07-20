"""Phase 5 acceptance check: verifies the rendered melody has the correct
notes in the correct time order (segments the audio into expected note
windows, FFT-checks the dominant frequency in each)."""

import sys
import wave
import numpy as np

from fft_utils import dominant_freq

SAMPLE_RATE_HZ = 48_000
NOTE_HOLD_SAMPLES = 4800
MELODY = [("C4", 261.63), ("D4", 293.66), ("E4", 329.63), ("D4", 293.66), ("C4", 261.63)]


def load_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wf:
        n = wf.getnframes()
        raw = wf.readframes(n)
    return np.frombuffer(raw, dtype=np.int16)


if __name__ == "__main__":
    samples = load_wav("samples_melody.wav")
    ok = True

    for i, (name, target_freq) in enumerate(MELODY):
        window_start = i * NOTE_HOLD_SAMPLES
        # use the middle of the note's window (skip attack transient at the start
        # and any bleed from the next note-on near the end)
        seg_start = window_start + 1200
        seg_end = window_start + 3600
        segment = samples[seg_start:seg_end]
        if len(segment) == 0:
            print(f"  FAIL: note {i} ({name}) window is empty -- audio too short")
            ok = False
            continue
        measured = dominant_freq(segment, SAMPLE_RATE_HZ)
        err_hz = abs(measured - target_freq)
        status = "PASS" if err_hz < 5.0 else "FAIL"
        if err_hz >= 5.0:
            ok = False
        print(f"  note {i} ({name}): target={target_freq}Hz measured={measured:.2f}Hz error={err_hz:.2f}Hz [{status}]")

    print(f"\nPhase 5 acceptance: {'PASS' if ok else 'FAIL'} (correct notes in correct order/timing)")
    sys.exit(0 if ok else 1)
