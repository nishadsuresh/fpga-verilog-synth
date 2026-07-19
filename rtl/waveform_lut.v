// waveform_lut.v — generates sine/saw/square/triangle from a shared 32-bit
// phase accumulator, so all four waveforms stay pitch-locked to the same NCO.
// wave_select: 0=sine (via LUT), 1=saw, 2=square, 3=triangle.
//
// phase_norm = phase_acc[31:16], an unsigned 16-bit value sweeping 0..65535
// once per cycle -- every other waveform is built directly from this.

module waveform_lut #(
    parameter PHASE_WIDTH    = 32,
    parameter LUT_ADDR_WIDTH = 10,
    parameter DATA_WIDTH     = 16
) (
    input  wire [PHASE_WIDTH-1:0]   phase_acc,
    input  wire [1:0]               wave_select,
    output reg  signed [DATA_WIDTH-1:0] sample_out
);

    localparam signed [DATA_WIDTH-1:0] AMPLITUDE = 30000;

    reg signed [DATA_WIDTH-1:0] sine_lut [0:(1<<LUT_ADDR_WIDTH)-1];
    initial $readmemh("sine_lut.mem", sine_lut);

    wire [LUT_ADDR_WIDTH-1:0] lut_addr = phase_acc[PHASE_WIDTH-1 -: LUT_ADDR_WIDTH];
    wire signed [DATA_WIDTH-1:0] sine_val = sine_lut[lut_addr];

    wire [15:0] phase_norm = phase_acc[31:16];  // 0..65535 once per cycle

    // saw: linear ramp from -AMPLITUDE (phase_norm=0) to +AMPLITUDE (phase_norm=65535)
    // (2*AMPLITUDE*phase_norm) fits in 32 bits: 2*30000*65535 ~= 3.93e9 < 2^32
    wire signed [DATA_WIDTH-1:0] saw_val = -AMPLITUDE + ((32'd2 * AMPLITUDE * phase_norm) >> 16);

    // square: first half of cycle low, second half high
    wire signed [DATA_WIDTH-1:0] square_val = phase_acc[31] ? AMPLITUDE : -AMPLITUDE;

    // triangle: rising -AMPLITUDE->+AMPLITUDE over first half, falling back over second half
    wire signed [DATA_WIDTH-1:0] tri_val = phase_acc[31]
        ? ( AMPLITUDE - ((32'd2 * AMPLITUDE * (phase_norm - 16'd32768)) >> 15))
        : (-AMPLITUDE + ((32'd2 * AMPLITUDE * phase_norm) >> 15));

    always @(*) begin
        case (wave_select)
            2'd0: sample_out = sine_val;
            2'd1: sample_out = saw_val;
            2'd2: sample_out = square_val;
            2'd3: sample_out = tri_val;
            default: sample_out = sine_val;
        endcase
    end

endmodule
