// nco.v — numerically-controlled oscillator: 32-bit phase accumulator
// indexing a 1024-entry sine LUT. phase_increment sets the output frequency:
// phase_increment = round(freq_hz * 2^32 / sample_rate_hz).
// sample_out updates combinationally from the current phase — no extra
// latency between phase_acc advancing and the LUT read.

module nco #(
    parameter PHASE_WIDTH     = 32,
    parameter LUT_ADDR_WIDTH  = 10,   // 1024 entries
    parameter LUT_DATA_WIDTH  = 16
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          sample_tick,
    input  wire [PHASE_WIDTH-1:0]        phase_increment,
    output wire signed [LUT_DATA_WIDTH-1:0] sample_out
);

    reg [PHASE_WIDTH-1:0] phase_acc;
    reg signed [LUT_DATA_WIDTH-1:0] sine_lut [0:(1<<LUT_ADDR_WIDTH)-1];

    initial $readmemh("sine_lut.mem", sine_lut);

    wire [LUT_ADDR_WIDTH-1:0] lut_addr = phase_acc[PHASE_WIDTH-1 -: LUT_ADDR_WIDTH];
    assign sample_out = sine_lut[lut_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= {PHASE_WIDTH{1'b0}};
        end else if (sample_tick) begin
            phase_acc <= phase_acc + phase_increment;
        end
    end

endmodule
