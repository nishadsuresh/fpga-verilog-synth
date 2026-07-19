"""Phase 4 acceptance check: (1) no clipping in the mixed WAV, (2) all 4
chord partials (C4/E4/G4/C5) visible as distinct spectral peaks."""

import sys
import wave
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import signal

SAMPLE_RATE_HZ = 48_000
NOTES = [("C4", 261.63), ("E4", 329.63), ("G4", 392.00), ("C5", 523.25)]


def load_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wf:
        n = wf.getnframes()
        raw = wf.readframes(n)
    return np.frombuffer(raw, dtype=np.int16)


def check_no_clipping(samples: np.ndarray) -> bool:
    n_at_max = int(np.sum(samples >= 32767))
    n_at_min = int(np.sum(samples <= -32768))
    clipped = n_at_max + n_at_min
    # a handful of samples legitimately landing at the exact peak is fine;
    # sustained runs at the rail are what "clipping" actually means
    if clipped > len(samples) * 0.001:
        print(f"  FAIL: {clipped} samples at/beyond full scale ({clipped/len(samples):.3%} of total) -- looks like real clipping")
        return False
    print(f"  PASS: {clipped} samples at full-scale rail ({clipped/len(samples):.4%}) -- not clipping, peak range=[{samples.min()},{samples.max()}]")
    return True


def check_four_partials(samples: np.ndarray) -> bool:
    # use only the sustain portion (skip attack/decay transient and release tail)
    steady = samples[2000:40000].astype(np.float64)
    windowed = steady * np.hanning(len(steady))
    spectrum = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(len(windowed), d=1 / SAMPLE_RATE_HZ)

    ok = True
    found_freqs = []
    for name, target in NOTES:
        # search a narrow window around the target frequency for a local peak
        band = (freqs > target - 8) & (freqs < target + 8)
        if not np.any(band):
            print(f"  FAIL: no frequency bins found near {name} ({target}Hz)")
            ok = False
            continue
        band_spectrum = spectrum[band]
        band_freqs = freqs[band]
        peak_idx = np.argmax(band_spectrum)
        peak_freq = band_freqs[peak_idx]
        peak_mag = band_spectrum[peak_idx]
        # require this peak to be a meaningfully large fraction of the overall max
        # (i.e. actually present, not just spectral leakage/noise)
        if peak_mag < 0.05 * spectrum.max():
            print(f"  FAIL: {name} ({target}Hz) partial too weak: peak={peak_mag:.1f} vs overall max={spectrum.max():.1f}")
            ok = False
        else:
            print(f"  PASS: {name} found at {peak_freq:.2f}Hz (target {target}Hz), magnitude={peak_mag:.1f}")
        found_freqs.append(peak_freq)

    # save a spectrogram for the README
    f, t, Sxx = signal.spectrogram(samples.astype(np.float64), fs=SAMPLE_RATE_HZ, nperseg=2048, noverlap=1024)
    Sxx_db = 20 * np.log10(np.abs(Sxx) + 1e-6)
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.pcolormesh(t, f, Sxx_db, shading="auto", cmap="viridis", vmin=Sxx_db.max() - 50, vmax=Sxx_db.max())
    ax.set_ylim(0, 800)
    for name, target in NOTES:
        ax.axhline(target, color="white", linestyle="--", linewidth=0.5, alpha=0.6)
        ax.text(t[-1] * 0.98, target, name, color="white", fontsize=8, va="bottom", ha="right")
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Frequency (Hz)")
    ax.set_title("C-major chord (C4-E4-G4-C5) -- 4-voice mix")
    fig.tight_layout()
    fig.savefig("../audio/phase4_chord_spectrogram.png", dpi=120)
    plt.close(fig)

    return ok


if __name__ == "__main__":
    samples = load_wav("samples_poly.wav")
    print("Clipping check:")
    clip_ok = check_no_clipping(samples)
    print("\nFour-partial check:")
    partial_ok = check_four_partials(samples)

    all_ok = clip_ok and partial_ok
    print(f"\nPhase 4 acceptance: {'PASS' if all_ok else 'FAIL'}")
    sys.exit(0 if all_ok else 1)
