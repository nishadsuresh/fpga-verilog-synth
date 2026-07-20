// adsr.v — attack/decay/sustain/release envelope generator.
// envelope output is unsigned, 0 to ENV_MAX, meant to be multiplied against
// a waveform sample (scaled down) by the mixer in a later phase.
//
// gate=1 starts attack (or re-triggers from wherever the envelope currently
// is, if already active); gate=0 starts release from the current level.

module adsr #(
    parameter ENV_WIDTH = 16,
    parameter COUNTER_WIDTH = 24
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      sample_tick,
    input  wire                      gate,
    input  wire [COUNTER_WIDTH-1:0]  attack_samples,
    input  wire [COUNTER_WIDTH-1:0]  decay_samples,
    input  wire [ENV_WIDTH-1:0]      sustain_level,   // 0..ENV_MAX
    input  wire [COUNTER_WIDTH-1:0]  release_samples,
    output reg  [ENV_WIDTH-1:0]      envelope
);

    localparam [ENV_WIDTH-1:0] ENV_MAX = {ENV_WIDTH{1'b1}};
    localparam PRODUCT_WIDTH = ENV_WIDTH + COUNTER_WIDTH;  // wide enough for any ENV_WIDTH-bit x COUNTER_WIDTH-bit product, no truncation

    localparam ST_IDLE    = 3'd0;
    localparam ST_ATTACK  = 3'd1;
    localparam ST_DECAY   = 3'd2;
    localparam ST_SUSTAIN = 3'd3;
    localparam ST_RELEASE = 3'd4;

    reg [2:0] state;
    reg [COUNTER_WIDTH-1:0] counter;
    reg [ENV_WIDTH-1:0] release_start_level;
    reg [ENV_WIDTH-1:0] attack_start_level;
    reg gate_prev;

    // explicit wide intermediates -- avoids relying on Verilog's self-determined
    // multiply-width inference, which does NOT automatically widen to fit the
    // full product (a 16-bit x 24-bit multiply computed at only 24-bit width
    // silently truncates: 65535*479 needs 25 bits, overflowing a 24-bit result).
    //
    // attack_product ramps from attack_start_level (the envelope level at the
    // moment of retrigger, not always 0) up to ENV_MAX -- a retrigger mid-decay
    // or mid-release used to snap straight to 0 before ramping back up (an
    // audible click), contradicting this module's own header comment. Captured
    // the same way release already captures release_start_level.
    wire [PRODUCT_WIDTH-1:0] attack_product  = {{COUNTER_WIDTH{1'b0}}, (ENV_MAX - attack_start_level)} * counter;
    wire [PRODUCT_WIDTH-1:0] decay_product   = {{COUNTER_WIDTH{1'b0}}, (ENV_MAX - sustain_level)} * counter;
    wire [PRODUCT_WIDTH-1:0] release_product = {{COUNTER_WIDTH{1'b0}}, release_start_level} * counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            envelope <= {ENV_WIDTH{1'b0}};
            counter <= 0;
            release_start_level <= 0;
            attack_start_level <= 0;
            gate_prev <= 1'b0;
        end else if (sample_tick) begin
            gate_prev <= gate;

            if (gate && !gate_prev) begin
                // rising edge: (re)start attack, ramping from wherever the
                // envelope currently is (not always 0) up to ENV_MAX
                state <= ST_ATTACK;
                counter <= 0;
                attack_start_level <= envelope;
            end else if (!gate && gate_prev) begin
                // falling edge: start release from current level
                state <= ST_RELEASE;
                counter <= 0;
                release_start_level <= envelope;
            end else begin
                case (state)
                    ST_IDLE: envelope <= {ENV_WIDTH{1'b0}};

                    ST_ATTACK: begin
                        if (attack_samples == 0 || counter >= attack_samples) begin
                            envelope <= ENV_MAX;
                            state <= ST_DECAY;
                            counter <= 0;
                        end else begin
                            envelope <= attack_start_level + (attack_product / attack_samples);
                            counter <= counter + 1;
                        end
                    end

                    ST_DECAY: begin
                        if (decay_samples == 0 || counter >= decay_samples) begin
                            envelope <= sustain_level;
                            state <= ST_SUSTAIN;
                            counter <= 0;
                        end else begin
                            envelope <= ENV_MAX - (decay_product / decay_samples);
                            counter <= counter + 1;
                        end
                    end

                    ST_SUSTAIN: begin
                        envelope <= sustain_level;
                    end

                    ST_RELEASE: begin
                        if (release_samples == 0 || counter >= release_samples) begin
                            envelope <= {ENV_WIDTH{1'b0}};
                            state <= ST_IDLE;
                            counter <= 0;
                        end else begin
                            envelope <= release_start_level - (release_product / release_samples);
                            counter <= counter + 1;
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
