// synth_top.v — top-level: MIDI UART in -> uart_midi -> note_lut -> nco ->
// adsr -> mixer -> audio out. The wiring exactly mirrors sim/tb_melody.v's
// proven single-voice chain, but routed through mixer.v (voice0 carries the
// live note; voices 1-3 are tied to silence) so the mixer's overflow-proof
// scaling is genuinely exercised at the top level, not just in its own
// isolated testbench.
//
// SCOPE NOTE: uart_midi.v tracks exactly one active note/gate pair, so this
// is a real, fully-wired MONOPHONIC synth -- the "4-voice" mixer capacity
// (proven independently in tb_poly.v/tb_mixer.v) isn't reachable from a live
// MIDI stream yet. True MIDI polyphony would need a voice-allocator module
// tracking up to 4 concurrently-held notes; that's real future work, not
// implemented here.
//
// Because voices 1-3 are silent, mixer.v's mandatory >>>2 headroom shift
// quarter-attenuates the single active voice relative to driving nco/adsr
// directly (see the project README's "honest limitations" section, which
// already documents this loudness-for-safety tradeoff).

module synth_top #(
    parameter CLK_FREQ_HZ    = 100_000_000,
    parameter SAMPLE_RATE_HZ = 48_000,
    parameter BAUD_RATE      = 31_250,
    parameter [23:0] ATTACK_SAMPLES  = 240,   // 5ms, matches tb_melody.v
    parameter [23:0] DECAY_SAMPLES   = 240,   // 5ms
    parameter [15:0] SUSTAIN_LEVEL   = 16'd55000,
    parameter [23:0] RELEASE_SAMPLES = 960    // 20ms
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        midi_rx,
    output reg  signed [15:0] audio_sample,
    output reg          sample_tick
);

    localparam integer DIVIDER = CLK_FREQ_HZ / SAMPLE_RATE_HZ;
    integer clk_counter;
    reg sample_tick_int;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter     <= 0;
            sample_tick_int <= 1'b0;
        end else if (clk_counter == DIVIDER - 1) begin
            clk_counter     <= 0;
            sample_tick_int <= 1'b1;
        end else begin
            clk_counter     <= clk_counter + 1;
            sample_tick_int <= 1'b0;
        end
    end

    wire [6:0]  midi_note;
    wire        midi_gate;
    wire        midi_note_valid;

    uart_midi #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_midi (
        .clk(clk), .rst_n(rst_n), .rx(midi_rx),
        .note(midi_note), .gate(midi_gate), .note_valid(midi_note_valid)
    );

    wire [31:0] phase_increment;
    note_lut u_note_lut (
        .midi_note(midi_note),
        .phase_increment(phase_increment)
    );

    wire signed [15:0] voice0_sample;
    nco u_nco (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick_int),
        .phase_increment(phase_increment),
        .sample_out(voice0_sample)
    );

    wire [15:0] voice0_env;
    adsr #(
        .ENV_WIDTH(16),
        .COUNTER_WIDTH(24)
    ) u_adsr (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick_int),
        .gate(midi_gate),
        .attack_samples(ATTACK_SAMPLES),
        .decay_samples(DECAY_SAMPLES),
        .sustain_level(SUSTAIN_LEVEL),
        .release_samples(RELEASE_SAMPLES),
        .envelope(voice0_env)
    );

    wire signed [15:0] mixed_out;
    mixer u_mixer (
        .voice0_sample(voice0_sample), .voice0_env(voice0_env),
        .voice1_sample(16'sd0),        .voice1_env(16'd0),
        .voice2_sample(16'sd0),        .voice2_env(16'd0),
        .voice3_sample(16'sd0),        .voice3_env(16'd0),
        .mixed_out(mixed_out)
    );

    // Same capture convention sim/tb_melody.v already uses and has verified
    // correct (5/5 notes, right timing): audio_sample is captured on the
    // same sample_tick_int edge that also drives nco/adsr, so it lags their
    // freshly-computed values by one sample -- a constant one-sample offset
    // across the whole waveform, invisible to pitch (FFT) and note-timing
    // checks alike. Kept consistent with that proven pattern rather than
    // adding an extra pipeline stage that would only diverge from it.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_sample <= 16'sd0;
            sample_tick  <= 1'b0;
        end else begin
            sample_tick <= sample_tick_int;
            if (sample_tick_int) audio_sample <= mixed_out;
        end
    end

endmodule
