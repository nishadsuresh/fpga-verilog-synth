"""Generates rtl/sine_lut.mem: a 1024-entry, 16-bit signed sine lookup table
in $readmemh-compatible hex format (one full cycle, 0 to 2*pi).

Amplitude is 30000 (not 32767) to leave headroom for later phases (ADSR
scaling, 4-voice mixing) without overflow before an explicit gain stage."""

import math

N = 1024
AMPLITUDE = 30000

with open("sine_lut.mem", "w") as f:
    for i in range(N):
        val = round(AMPLITUDE * math.sin(2 * math.pi * i / N))
        # two's complement 16-bit hex
        hex_val = val & 0xFFFF
        f.write(f"{hex_val:04x}\n")

print(f"Wrote {N}-entry sine LUT to sine_lut.mem (amplitude={AMPLITUDE})")
