// mixer.v — sums 4 voice samples with guaranteed headroom to avoid overflow.
// Each voice is first scaled by its own envelope (0..65535 -> ~0..1x), then
// the 4 scaled voices are summed and right-shifted by 2 (divide by 4): the
// true worst case is asymmetric (a signed 16-bit sample ranges -32768..32767),
// so 4 voices simultaneously at full scale sum to between -131072 and
// +131068. -131072>>>2 = -32768 and 131068>>>2 = 32767, both exactly in
// range -- so overflow is structurally impossible, not just statistically
// unlikely, across the true (not symmetrized) bound.
//
// Both multiply operands are explicitly pre-widened to PRODUCT_WIDTH before
// the `*` -- Verilog's self-determined multiply width does NOT automatically
// widen to fit the full product of narrower operands (this bit us once
// already in adsr.v), so this sidesteps that class of bug entirely rather
// than relying on width inference.

module mixer #(
    parameter DATA_WIDTH = 16,
    parameter ENV_WIDTH  = 16
) (
    input  wire signed [DATA_WIDTH-1:0] voice0_sample,
    input  wire        [ENV_WIDTH-1:0]  voice0_env,
    input  wire signed [DATA_WIDTH-1:0] voice1_sample,
    input  wire        [ENV_WIDTH-1:0]  voice1_env,
    input  wire signed [DATA_WIDTH-1:0] voice2_sample,
    input  wire        [ENV_WIDTH-1:0]  voice2_env,
    input  wire signed [DATA_WIDTH-1:0] voice3_sample,
    input  wire        [ENV_WIDTH-1:0]  voice3_env,
    output wire signed [DATA_WIDTH-1:0] mixed_out
);

    localparam PRODUCT_WIDTH = DATA_WIDTH + ENV_WIDTH + 2;  // generous margin, verified adequate by simulation

    function automatic signed [PRODUCT_WIDTH-1:0] scale_voice;
        input signed [DATA_WIDTH-1:0] sample;
        input [ENV_WIDTH-1:0] env;
        reg signed [PRODUCT_WIDTH-1:0] wide_sample;
        reg signed [PRODUCT_WIDTH-1:0] wide_env;
        begin
            wide_sample = {{(PRODUCT_WIDTH-DATA_WIDTH){sample[DATA_WIDTH-1]}}, sample}; // sign-extend
            wide_env    = {{(PRODUCT_WIDTH-ENV_WIDTH){1'b0}}, env};                     // zero-extend (env is unsigned)
            scale_voice = (wide_sample * wide_env) >>> ENV_WIDTH;
        end
    endfunction

    wire signed [DATA_WIDTH-1:0] v0 = scale_voice(voice0_sample, voice0_env);
    wire signed [DATA_WIDTH-1:0] v1 = scale_voice(voice1_sample, voice1_env);
    wire signed [DATA_WIDTH-1:0] v2 = scale_voice(voice2_sample, voice2_env);
    wire signed [DATA_WIDTH-1:0] v3 = scale_voice(voice3_sample, voice3_env);

    // sum in a wider register to avoid overflow before the final headroom shift
    wire signed [DATA_WIDTH+1:0] sum = v0 + v1 + v2 + v3;
    assign mixed_out = sum >>> 2;

endmodule
