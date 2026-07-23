# FPGA Verilog Music Synthesizer

**Nishad Suresh**

## Abstract

This project implements a music synthesizer at the digital-logic level in Verilog: a numerically controlled oscillator (NCO), an ADSR envelope generator, a 4-voice mixer, and a UART-based MIDI receiver, wired into a real MIDI-in-to-audio-out signal chain and verified entirely in HDL simulation (Icarus Verilog and GTKWave), with audio rendered to real, listenable WAV files. No FPGA board is used; simulation is the standard verification step in real digital-chip design prior to synthesis and tapeout, and is the basis for every result reported here. Pitch accuracy measured via FFT with sub-bin interpolation came out at approximately 0.0000 cents error at all tested frequencies. The mixer is independently proven 4-voice-polyphonic; the top-level integration (`synth_top.v`) is a genuine, fully wired, monophonic MIDI-in-to-audio-out design, with the exact scope boundary between those two claims documented in the Limitations section below.

**Status:** all 6 phases complete.

## 1. Motivation

Verilog is the language used to describe real digital hardware prior to fabrication, and this project was built to exercise that discipline directly rather than working only at a software level. Every phase was verified two ways: numerically (FFT-based pitch measurement, envelope-shape checks, clipping checks) and audibly, since every phase produces a real, listenable WAV file.

## 2. Architecture

```
UART MIDI in -> uart_midi.v -> note_lut.v -> nco.v (phase accumulator + sine LUT)
                                                  |
                gate ----------------------> adsr.v (envelope)
                                                  |
                              [x4 voices] -----------> mixer.v -> audio out
```

`synth_top.v` implements this diagram as a real, simulated, and verified MIDI-in-to-audio-out module, not simply a collection of independently working modules. See Section 6 for the one real scope boundary in that integration.

## 3. Modules

**`nco.v`** -- 32-bit phase-accumulator numerically controlled oscillator with a 1024-entry sine lookup table.

**`waveform_lut.v`** -- sine, saw, square, and triangle waveforms generated from the same phase accumulator.

**`adsr.v`** -- attack/decay/sustain/release envelope state machine.

**`mixer.v`** -- sums up to 4 voices with structurally overflow-proof headroom (a right-shift by 2 rather than a saturating clamp, making overflow mathematically impossible rather than merely avoided in practice).

**`uart_midi.v`** -- UART receiver (8-N-1) with a MIDI Note On/Off parser.

**`note_lut.v`** -- maps MIDI note number to NCO phase increment.

## 4. Setup

Requires Icarus Verilog (`iverilog`, `vvp`) and GTKWave for waveform viewing, plus Python 3 with `numpy`, `scipy`, and `matplotlib`.

```bash
sudo apt-get install iverilog gtkwave  # Debian/Ubuntu/WSL

make wav      # synth_top.v end to end: sends a real MIDI note, renders the resulting audio
make phase2   # NCO pitch accuracy check
make phase3   # ADSR + waveform shape check
make phase4   # 4-voice mixer, C-major chord, clipping + partials check
make phase5   # UART-MIDI melody through the individual module chain, note/timing check
```

## 5. Methodology and Results

| # | Phase | Acceptance test | Result |
|---|---|---|---|
| 1 | Repo + sim harness + WAV renderer | Stub renders valid silent WAV | ✅ `audio/phase1_silence.wav` (historical, see Section 6) |
| 2 | NCO + sine LUT | \|error\| < 5 cents at A2/A4/A6 | ✅ ~0.0000 cents at all three (Section 5.1) |
| 3 | ADSR + waveform select | Envelope shape matches spec | ✅ verified numerically (monotonic A/D/R, exact sustain hold, Section 5.4) |
| 4 | 4-voice mixer, C-major chord | No clipping, 4 partials present | ✅ 0 clipped samples, all 4 partials confirmed via FFT |
| 5 | UART-MIDI melody | Correct notes and timing | ✅ 5/5 notes correct, average error 0.6 Hz (Section 5.3) |
| 6 | `synth_top.v` wired end to end | Real MIDI note in, correct audio out via the top-level module | ✅ 0.40 Hz pitch error, correct silence/gate behavior (Section 6) |

### 5.1 Pitch accuracy (Phase 2)

| Note | Target | Measured | Error |
|---|---|---|---|
| A2 | 110.0 Hz | 110.0000 Hz | -0.0000 cents |
| A4 | 440.0 Hz | 440.0000 Hz | -0.0000 cents |
| A6 | 1760.0 Hz | 1760.0000 Hz | +0.0000 cents |

Pitch was measured via FFT with parabolic sub-bin interpolation (`sim/check_pitch.py`), far under the 5-cent target, consistent with a bit-exact NCO/LUT design with no analog imperfections.

### 5.2 Audio artifacts

`audio/synth_top_demo.wav` is the top-level result: a MIDI note-on/off sent through `synth_top.v`'s wired integration (C4, 128ms).

`audio/phase1_silence.wav` is retained as a historical record of the original Phase 1 stub's silent output and is not representative of the project's current behavior.

`audio/phase4_chord.wav` and `audio/phase4_chord_spectrogram.png` show a 4-voice C-major chord (C4-E4-G4-C5) driven directly at the module level (`tb_poly.v`), demonstrating the mixer's polyphonic capability independent of `synth_top.v`'s current monophonic MIDI path.

`audio/phase5_melody.wav` and `audio/phase5_melody_spectrogram.png` show a UART-MIDI-driven melody (C4-D4-E4-D4-C4) through the individual module chain (`tb_melody.v`), predating the `synth_top.v` fix described in Section 6.

### 5.3 UART-MIDI melody spectrogram

![melody spectrogram](audio/phase5_melody_spectrogram.png)

A clean note staircase (C4 → D4 → E4 → D4 → C4), with each transition landing exactly where the MIDI stream commands it.

### 5.4 Envelope verification (Phase 3)

The original acceptance test was a visual check of envelope shape in GTKWave. This was replaced with `sim/check_adsr.py`, which verifies the same property numerically: attack ramps monotonically to maximum, decay ramps monotonically to the sustain level and holds it exactly, and release ramps monotonically to zero. The waveform is still generated (`sim/tb_adsr.vcd`) for direct inspection in GTKWave if desired.

## 6. The synth_top.v Integration

Each module described above (`nco`, `adsr`, `mixer`, `uart_midi`, `note_lut`) was individually built and verified in its own testbench. For a period, however, `synth_top.v` -- the module intended to wire all of them together into one real MIDI-in-to-audio-out design -- remained the original Phase 1 stub, silently outputting constant zero despite the project's own documentation claiming full integration. This was caught during a later independent quality-review pass that specifically checked whether the file did what its own header comment and this README claimed. It was fixed by actually instantiating and wiring the full chain (`uart_midi -> note_lut -> nco -> adsr -> mixer`), with a new testbench (`sim/tb_synth_top.v`, `sim/check_synth_top.py`) that sends a real MIDI note-on/off over simulated UART into `synth_top`'s pins and checks the resulting audio for correct pitch (0.40 Hz error), correct silence before the note arrives, and correct decay to silence after release. `audio/synth_top_demo.wav` is the result.

`uart_midi.v` tracks exactly one active note/gate pair, so `synth_top.v` as wired is a genuine, fully end-to-end monophonic synthesizer: a live MIDI stream cannot yet trigger true 4-voice polyphony, even though the mixer itself is independently proven to handle 4 simultaneous voices (Phase 4, `tb_poly.v`/`tb_mixer.v`). Reaching a MIDI-driven 4-voice synth would require a voice-allocator module tracking up to 4 concurrently-held notes, which is not implemented here.

**Two bugs were caught and fixed during verification.** The first was found while replacing a visual ADSR check with the numeric test described in Section 5.4: a 16-bit by 24-bit multiply was computed at only 24-bit width, since Verilog does not automatically widen the result of `*` to fit the full product, silently overflowing the attack/decay/release ramp calculations. The numeric check caught this immediately (attack topped out at 46% of maximum instead of approximately 100%), where a purely visual GTKWave check might have appeared correct at a glance. It was fixed with explicit wide intermediate values (see the comments in `rtl/adsr.v`). The second was caught in a later quality pass: `adsr.v`'s own header comment claimed that a retrigger (the gate going high again while already mid-decay or mid-release) resumes "from wherever the envelope currently is," but the code actually snapped the envelope to zero first and then ramped back up, which would produce an audible click. This was fixed by capturing the envelope's level at the moment of retrigger (`attack_start_level`, following the same pattern already used for `release_start_level`) and ramping from that value instead of from zero. `sim/tb_adsr_retrigger.v` and `sim/check_adsr_retrigger.py` are a new regression test for this scenario.

## 7. Limitations

**No FPGA board.** Everything here is simulation-only, by design (Section 1). The RTL is written to be synthesizable but has not been run through a synthesis tool or placed on real hardware.

**`synth_top.v` is monophonic, not polyphonic, from a live MIDI stream.** `uart_midi.v` tracks exactly one active note/gate pair at a time, so the wired-together top level can sound only one note at once. The mixer itself genuinely handles 4 simultaneous voices (Phase 4, `tb_poly.v`), but nothing currently allocates a live MIDI note stream across multiple voices.

**Five-note melody, not a full MIDI implementation.** `note_lut.v` covers the notes used in the demo melody via a lookup table (the standard real-world approach, since computing 2^x in hardware is impractical), not the full 128-note MIDI range. Extending it is a matter of adding table entries, not new logic.

**Mixer headroom trades loudness for guaranteed-safe arithmetic.** A single voice at full velocity is attenuated to 1/4 scale so that 4 simultaneous full-scale voices can never overflow, a deliberate structural safety choice over a more complex dynamic-gain approach.

## 8. Summary

This project implements a synthesizer in Verilog at the digital-logic level -- an NCO, an ADSR envelope, a proven 4-voice mixer, and a UART-MIDI parser -- wired into a real monophonic MIDI-in-to-audio-out top level, with pitch accuracy, envelope shape, voice mixing, and note timing verified entirely in HDL simulation. Verification caught and fixed two real bugs: a bit-width truncation and an envelope-retrigger click.

## References

Sources used to design, validate, and cross-check this project's methodology:

[1] Analog Devices, "MT-085 Tutorial: Fundamentals of Direct Digital Synthesis (DDS)," 2009. https://www.analog.com/media/en/training-seminars/tutorials/MT-085.pdf -- the phase-accumulator + lookup-table technique this synth's `nco.v` implements.

[2] Analog Devices, "A Technical Tutorial on Digital Signal Synthesis," 1999. https://www.analog.com/media/cn/training-seminars/tutorials/450968421DDS_Tutorial_rev12-2-99.pdf

[3] MIDI Association, "MIDI 1.0 Detailed Specification" (Note On/Off, running status, channel voice messages). https://midi.org/midi-1-0 -- protocol `uart_midi.v` parses.

[4] D. M. Harris and S. L. Harris, Digital Design and Computer Architecture, Morgan Kaufmann / Elsevier. https://www.sciencedirect.com/book/9780123944245/digital-design-and-computer-architecture -- general RTL/Verilog design reference used throughout.

[5] Icarus Verilog project documentation and source. https://steveicarus.github.io/iverilog/ and https://github.com/steveicarus/iverilog -- the simulator this project is verified with (`iverilog` / `vvp`).

[6] GTKWave documentation -- the waveform viewer used to inspect testbench signals during development. http://gtkwave.sourceforge.net/
