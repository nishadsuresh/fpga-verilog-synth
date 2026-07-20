"""synth_top.v integration acceptance check: sends a real MIDI note through
the fully-wired top-level chain (uart_midi -> note_lut -> nco -> adsr ->
mixer) and verifies (1) the sustained portion is C4 pitch within tolerance,
(2) it's silent before the note-on arrives, (3) it decays to silence after
note-off. This is what actually proves synth_top.v is wired correctly, as
opposed to each module's own isolated testbench."""

import sys
import wave
import numpy as np

from fft_utils import dominant_freq

SAMPLE_RATE_HZ = 48_000
TARGET_FREQ_HZ = 261.63  # C4
NOTE_HOLD_SAMPLES = 4800
RELEASE_SAMPLES = 960


def load_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wf:
        n = wf.getnframes()
        raw = wf.readframes(n)
    return np.frombuffer(raw, dtype=np.int16)


if __name__ == "__main__":
    samples = load_wav("samples.wav")
    ok = True

    # 1. sustained portion (skip attack/decay transient) matches C4
    seg = samples[1200:3600]
    measured = dominant_freq(seg, SAMPLE_RATE_HZ)
    err_hz = abs(measured - TARGET_FREQ_HZ)
    status = "PASS" if err_hz < 5.0 else "FAIL"
    if err_hz >= 5.0:
        ok = False
    print(f"  sustained pitch: target={TARGET_FREQ_HZ}Hz measured={measured:.2f}Hz error={err_hz:.2f}Hz [{status}]")

    # 2. silent before note-on: uart_midi/mixer should output exactly zero
    # while gate is still low (before the ADSR ever leaves ST_IDLE).
    # The 3-byte note-on message takes 960us to transmit at 31250 baud
    # (~46 samples at 48kHz) before gate can go high, so stop safely before
    # that -- window must not be widened without re-deriving this margin.
    pre_note = samples[:35]
    status = "PASS" if np.all(pre_note == 0) else "FAIL"
    if not np.all(pre_note == 0):
        ok = False
    print(f"  silent before note-on: max|sample|={np.abs(pre_note).max()} [{status}]")

    # 3. decays to near-silence well after release completes
    tail_start = NOTE_HOLD_SAMPLES + RELEASE_SAMPLES + 100
    tail = samples[tail_start:tail_start + 100]
    max_tail = int(np.abs(tail).max()) if len(tail) else -1
    status = "PASS" if len(tail) > 0 and max_tail < 50 else "FAIL"
    if not (len(tail) > 0 and max_tail < 50):
        ok = False
    print(f"  silent after release completes: max|sample|={max_tail} (threshold 50) [{status}]")

    print(f"\nsynth_top.v acceptance: {'PASS' if ok else 'FAIL'} (real MIDI note -> correct pitch, correct gate behavior, end to end)")
    sys.exit(0 if ok else 1)
