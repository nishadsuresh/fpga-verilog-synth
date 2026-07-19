# fpga-verilog-synth

A polyphonic music synthesizer designed at the raw digital-logic level in Verilog, fully verified in simulation (Icarus Verilog + GTKWave), rendered to real, listenable audio. No FPGA board — simulation is the professional proof here, the same way real chip design is verified before tapeout.

**Status: Phase 1 of 6** (repo scaffold + simulation harness + WAV renderer).

## Why this exists

Verilog is how real digital hardware actually gets described — this is the least "software-kid" project in the portfolio. Every phase is verified by simulation output you can either measure (pitch accuracy via FFT) or literally listen to.

## Setup

Requires [Icarus Verilog](http://bleyer.org/icarus/) (`iverilog`, `vvp`) and [GTKWave](https://gtkwave.sourceforge.net/) for waveform viewing, plus Python 3 (standard library only — no dependencies for `render_wav.py`).

```bash
sudo apt-get install iverilog gtkwave   # Debian/Ubuntu/WSL
make wav                                 # compile, simulate, render audio/phase1_silence.wav
make wave                                # compile, simulate, print gtkwave command to view
```

## Phases

| # | Phase | Acceptance test |
|---|---|---|
| 1 | Repo + sim harness + WAV renderer | Stub testbench renders silence to a valid WAV |
| 2 | Single-voice phase-accumulator NCO + sine LUT | A440 renders within a few cents (FFT-measured) |
| 3 | ADSR envelope + waveform select | Envelope shape matches spec in GTKWave |
| 4 | 4-voice polyphony + mixer | Clean mixed chord WAV, no clipping, 4 partials present |
| 5 | UART-MIDI parser + melody render | Recognizable tune, correct notes/timing |
| 6 | README with audio demos + spectrograms + cents-accuracy table | A listenable, provably-correct open-source repo |

## Structure

```
rtl/       nco.v  waveform_lut.v  adsr.v  mixer.v  uart_midi.v  synth_top.v
sim/       tb_*.v testbenches + render_wav.py
audio/     rendered demo WAVs + spectrogram PNGs
docs/      block diagram, cents-accuracy table
```

## One-line summary

I designed a polyphonic synthesizer in Verilog at the digital-logic level and verified its pitch accuracy and voice mixing entirely in HDL simulation.
