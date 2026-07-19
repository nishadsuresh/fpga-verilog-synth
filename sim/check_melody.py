"""Phase 5 acceptance check: verifies the rendered melody has the correct
notes in the correct time order (segments the audio into expected note
windows, FFT-checks the dominant frequency in each)."""

import sys
import wave
import numpy as np

SAMPLE_RATE_HZ = 48_000
NOTE_HOLD_SAMPLES = 4800
MELODY = [("C4", 261.63), ("D4", 293.66), ("E4", 329.63), ("D4", 293.66), ("C4", 261.63)]


def load_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wf:
        n = wf.getnframes()
        raw = wf.readframes(n)
    return np.frombuffer(raw, dtype=np.int16)


def dominant_freq(segment: np.ndarray) -> float:
    """FFT peak with parabolic interpolation for sub-bin accuracy -- a plain
    argmax is only accurate to the bin width (here 48000/len(segment) Hz,
    far coarser than the few-Hz tolerance needed), same technique as
    sim/check_pitch.py's Phase 2 cents check."""
    windowed = segment.astype(np.float64) * np.hanning(len(segment))
    spectrum = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(len(windowed), d=1 / SAMPLE_RATE_HZ)

    peak_bin = int(np.argmax(spectrum))
    if peak_bin == 0 or peak_bin == len(spectrum) - 1:
        return float(freqs[peak_bin])

    y0, y1, y2 = spectrum[peak_bin - 1], spectrum[peak_bin], spectrum[peak_bin + 1]
    denom = y0 - 2 * y1 + y2
    delta = 0.5 * (y0 - y2) / denom if denom != 0 else 0.0
    bin_width = freqs[1] - freqs[0]
    return float(freqs[peak_bin] + delta * bin_width)


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
        measured = dominant_freq(segment)
        err_hz = abs(measured - target_freq)
        status = "PASS" if err_hz < 5.0 else "FAIL"
        if err_hz >= 5.0:
            ok = False
        print(f"  note {i} ({name}): target={target_freq}Hz measured={measured:.2f}Hz error={err_hz:.2f}Hz [{status}]")

    print(f"\nPhase 5 acceptance: {'PASS' if ok else 'FAIL'} (correct notes in correct order/timing)")
    sys.exit(0 if ok else 1)
