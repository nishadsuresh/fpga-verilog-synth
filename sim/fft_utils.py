"""Shared FFT pitch-measurement helper: used by check_pitch.py, check_melody.py,
and check_synth_top.py, which each independently need the dominant frequency
of an audio segment to sub-bin accuracy. Previously duplicated verbatim in
all three; factored out here after a quality pass flagged the duplication."""

import numpy as np


def dominant_freq(segment: np.ndarray, sample_rate_hz: float) -> float:
    """FFT peak with parabolic interpolation (quadratic fit through the peak
    bin and its two neighbors) for sub-bin-resolution frequency estimation --
    a plain argmax is only accurate to the bin width, far coarser than the
    few-Hz/few-cent tolerances these scripts check against."""
    windowed = segment.astype(np.float64) * np.hanning(len(segment))
    spectrum = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(len(windowed), d=1 / sample_rate_hz)

    peak_bin = int(np.argmax(spectrum))
    if peak_bin == 0 or peak_bin == len(spectrum) - 1:
        return float(freqs[peak_bin])

    y0, y1, y2 = spectrum[peak_bin - 1], spectrum[peak_bin], spectrum[peak_bin + 1]
    denom = y0 - 2 * y1 + y2
    delta = 0.5 * (y0 - y2) / denom if denom != 0 else 0.0
    bin_width = freqs[1] - freqs[0]
    return float(freqs[peak_bin] + delta * bin_width)
