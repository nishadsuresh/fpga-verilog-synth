"""Reads decimal samples (one per line) written by a testbench and renders a
valid 16-bit PCM WAV file at 48kHz. Used by every phase's testbench — later
phases just point it at a different samples.txt."""

from __future__ import annotations

import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE_HZ = 48_000


def render_wav(samples_path: Path, wav_path: Path, sample_rate: int = SAMPLE_RATE_HZ) -> int:
    with open(samples_path) as f:
        samples = [int(line.strip()) for line in f if line.strip()]

    for s in samples:
        if not (-32768 <= s <= 32767):
            raise ValueError(f"sample {s} out of 16-bit signed range — check for overflow in the RTL")

    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        packed = b"".join(struct.pack("<h", s) for s in samples)
        wf.writeframes(packed)

    return len(samples)


if __name__ == "__main__":
    samples_in = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("samples.txt")
    wav_out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("../audio/phase1_silence.wav")
    n = render_wav(samples_in, wav_out)
    print(f"Rendered {n} samples ({n / SAMPLE_RATE_HZ * 1000:.1f} ms) to {wav_out}")
