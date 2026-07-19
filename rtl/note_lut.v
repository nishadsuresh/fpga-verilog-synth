// note_lut.v — maps a MIDI note number to an NCO phase_increment.
// A lookup table (not computed 2^x in hardware) is the standard, practical
// approach for note->frequency in real synth designs. Covers the notes used
// by this project's demo melody; extend the case statement for more.

module note_lut (
    input  wire [6:0]  midi_note,
    output reg  [31:0] phase_increment
);
    // phase_increment = round(440 * 2^((note-69)/12) * 2^32 / 48000), computed in Python
    always @(*) begin
        case (midi_note)
            7'd60: phase_increment = 32'd23409859; // C4, 261.63 Hz
            7'd62: phase_increment = 32'd26276679; // D4, 293.66 Hz
            7'd64: phase_increment = 32'd29494575; // E4, 329.63 Hz
            default: phase_increment = 32'd0;
        endcase
    end
endmodule
