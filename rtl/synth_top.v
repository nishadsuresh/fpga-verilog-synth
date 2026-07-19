// synth_top.v — Phase 1 stub.
//
// Divides an input simulation clock down to a 48kHz sample_tick and outputs a
// constant-zero 16-bit signed audio sample on every tick. Later phases replace
// the constant-zero output with the actual NCO/ADSR/mixer signal chain — the
// clock-division and sample_tick interface stays the same throughout.

module synth_top #(
    parameter CLK_FREQ_HZ    = 100_000_000,
    parameter SAMPLE_RATE_HZ = 48_000
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg  signed [15:0] audio_sample,
    output reg          sample_tick
);

    localparam integer DIVIDER = CLK_FREQ_HZ / SAMPLE_RATE_HZ;
    integer clk_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter  <= 0;
            sample_tick  <= 1'b0;
            audio_sample <= 16'sd0;
        end else begin
            if (clk_counter == DIVIDER - 1) begin
                clk_counter  <= 0;
                sample_tick  <= 1'b1;
                audio_sample <= 16'sd0;  // Phase 1: silence. Real signal chain arrives in later phases.
            end else begin
                clk_counter <= clk_counter + 1;
                sample_tick <= 1'b0;
            end
        end
    end

endmodule
