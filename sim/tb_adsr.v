// tb_adsr.v — Phase 3 testbench. Drives gate through a full A/D/S/R cycle
// and dumps the envelope value every sample tick to envelope.txt for a
// numeric shape check (sim/check_adsr.py), in addition to the VCD for
// GTKWave. Also drives waveform_lut with a free-running phase counter and
// dumps one cycle of each of the 4 waveforms for a numeric shape check.

`timescale 1ns / 1ps

module tb_adsr;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;

    // ADSR timing, in samples
    localparam [23:0] ATTACK_SAMPLES  = 480;   // 10ms
    localparam [23:0] DECAY_SAMPLES   = 480;   // 10ms
    localparam [15:0] SUSTAIN_LEVEL   = 32768; // half of 65535
    localparam [23:0] RELEASE_SAMPLES = 480;   // 10ms

    localparam GATE_ON_SAMPLES  = 1500; // held on well past attack+decay, into sustain
    localparam TOTAL_SAMPLES    = GATE_ON_SAMPLES + RELEASE_SAMPLES + 100; // + margin after release completes

    reg clk = 0;
    reg rst_n = 0;
    reg gate = 0;
    reg sample_tick = 0;
    wire [15:0] envelope;

    adsr #(.ENV_WIDTH(16), .COUNTER_WIDTH(24)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate),
        .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES),
        .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES),
        .envelope(envelope)
    );

    // --- waveform_lut check: free-running phase, one full cycle each wave ---
    reg [31:0] wf_phase = 0;
    localparam [31:0] WF_PHASE_INC = 32'd39370534; // A4 (440Hz) -- fast enough for a short full-cycle dump
    wire signed [15:0] wf_sine, wf_saw, wf_square, wf_tri;
    waveform_lut wf0 (.phase_acc(wf_phase), .wave_select(2'd0), .sample_out(wf_sine));
    waveform_lut wf1 (.phase_acc(wf_phase), .wave_select(2'd1), .sample_out(wf_saw));
    waveform_lut wf2 (.phase_acc(wf_phase), .wave_select(2'd2), .sample_out(wf_square));
    waveform_lut wf3 (.phase_acc(wf_phase), .wave_select(2'd3), .sample_out(wf_tri));

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

    integer fd_env, fd_wf;
    integer sample_count = 0;

    initial begin
        $dumpfile("tb_adsr.vcd");
        $dumpvars(0, tb_adsr);

        fd_env = $fopen("envelope.txt", "w");
        fd_wf  = $fopen("waveform_samples.txt", "w");

        rst_n = 0;
        #100;
        rst_n <= 1;
        gate <= 1;

        while (sample_count < TOTAL_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                if (sample_count == GATE_ON_SAMPLES) gate <= 0;
                $fdisplay(fd_env, "%d", envelope);
                wf_phase = wf_phase + WF_PHASE_INC;
                $fdisplay(fd_wf, "%d %d %d %d", wf_sine, wf_saw, wf_square, wf_tri);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd_env);
        $fclose(fd_wf);
        $display("PHASE3_ACCEPTANCE: wrote %0d envelope samples, %0d waveform samples", sample_count, sample_count);
        $finish;
    end

endmodule
