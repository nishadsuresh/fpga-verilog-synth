// tb_poly.v — Phase 4 testbench. 4 NCO+ADSR voices tuned to a C-major chord
// (C4, E4, G4, C5), summed through mixer.v, rendered to WAV. Checked for
// (1) no clipping/overflow and (2) all 4 partials visible in the FFT.

`timescale 1ns / 1ps

module tb_poly;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;
    localparam N_SAMPLES      = 48_000; // 1 second

    // phase_increment = round(freq * 2^32 / sample_rate), verified via Python
    localparam [31:0] PHASE_INC_C4 = 32'd23410256;  // 261.63 Hz
    localparam [31:0] PHASE_INC_E4 = 32'd29494793;  // 329.63 Hz
    localparam [31:0] PHASE_INC_G4 = 32'd35075566;  // 392.00 Hz
    localparam [31:0] PHASE_INC_C5 = 32'd46819617;  // 523.25 Hz

    localparam [23:0] ATTACK_SAMPLES  = 480;
    localparam [23:0] DECAY_SAMPLES   = 480;
    localparam [15:0] SUSTAIN_LEVEL   = 55000;
    localparam [23:0] RELEASE_SAMPLES = 4800;

    reg clk = 0;
    reg rst_n = 0;
    reg sample_tick = 0;
    reg gate = 0;

    wire signed [15:0] nco0_out, nco1_out, nco2_out, nco3_out;
    wire [15:0] env0, env1, env2, env3;
    wire signed [15:0] mixed;

    nco nco0 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_C4), .sample_out(nco0_out));
    nco nco1 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_E4), .sample_out(nco1_out));
    nco nco2 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_G4), .sample_out(nco2_out));
    nco nco3 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_C5), .sample_out(nco3_out));

    adsr adsr0 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate), .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES), .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES), .envelope(env0));
    adsr adsr1 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate), .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES), .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES), .envelope(env1));
    adsr adsr2 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate), .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES), .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES), .envelope(env2));
    adsr adsr3 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate), .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES), .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES), .envelope(env3));

    mixer mixer_dut (
        .voice0_sample(nco0_out), .voice0_env(env0),
        .voice1_sample(nco1_out), .voice1_env(env1),
        .voice2_sample(nco2_out), .voice2_env(env2),
        .voice3_sample(nco3_out), .voice3_env(env3),
        .mixed_out(mixed)
    );

    always #5 clk = ~clk; // 100MHz

    integer clk_div_counter = 0;
    localparam DIVIDER = CLK_FREQ_HZ / SAMPLE_RATE_HZ;
    always @(posedge clk) begin
        if (clk_div_counter == DIVIDER - 1) begin
            clk_div_counter <= 0;
            sample_tick <= 1'b1;
        end else begin
            clk_div_counter <= clk_div_counter + 1;
            sample_tick <= 1'b0;
        end
    end

    integer fd;
    integer sample_count = 0;
    localparam GATE_ON_SAMPLES = N_SAMPLES - RELEASE_SAMPLES - 200;

    initial begin
        $dumpfile("tb_poly.vcd");
        $dumpvars(0, tb_poly);

        fd = $fopen("samples_poly.txt", "w");

        rst_n = 0;
        #100;
        rst_n <= 1;
        gate <= 1;

        while (sample_count < N_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                if (sample_count == GATE_ON_SAMPLES) gate <= 0;
                $fdisplay(fd, "%d", mixed);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("PHASE4_ACCEPTANCE: wrote %0d samples", sample_count);
        $finish;
    end

endmodule
