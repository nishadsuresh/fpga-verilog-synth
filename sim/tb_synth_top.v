// tb_synth_top.v — Phase 1 testbench.
//
// Drives synth_top for N_SAMPLES sample_ticks and writes each sample as a
// decimal integer, one per line, to samples.txt — sim/render_wav.py turns
// that into a real WAV file. Also dumps an FST waveform for GTKWave.

`timescale 1ns / 1ps

module tb_synth_top;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;
    localparam N_SAMPLES      = 4800;  // 100ms of audio at 48kHz

    reg clk = 0;
    reg rst_n = 0;
    wire signed [15:0] audio_sample;
    wire sample_tick;

    integer sample_count = 0;
    integer fd;

    synth_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SAMPLE_RATE_HZ(SAMPLE_RATE_HZ)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_tick(sample_tick)
    );

    // 100MHz clock: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_synth_top.vcd");
        $dumpvars(0, tb_synth_top);

        fd = $fopen("samples.txt", "w");
        if (fd == 0) begin
            $display("ERROR: could not open samples.txt for writing");
            $finish;
        end

        rst_n = 0;
        #100;
        rst_n = 1;

        while (sample_count < N_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                $fdisplay(fd, "%d", audio_sample);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("PHASE1_ACCEPTANCE: wrote %0d samples to samples.txt", sample_count);
        $finish;
    end

endmodule
