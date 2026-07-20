// tb_adsr_retrigger.v — regression test for the retrigger-snaps-to-0 bug:
// gate goes low mid-cycle (release starts), then high again *before* release
// finishes (retrigger). Per adsr.v's own header comment, the envelope should
// resume ramping from wherever it currently is, not snap to 0. Dumps
// envelope every tick to envelope_retrigger.txt for sim/check_adsr_retrigger.py.

`timescale 1ns / 1ps

module tb_adsr_retrigger;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;

    localparam [23:0] ATTACK_SAMPLES  = 480;   // 10ms
    localparam [23:0] DECAY_SAMPLES   = 480;   // 10ms
    localparam [15:0] SUSTAIN_LEVEL   = 32768;
    localparam [23:0] RELEASE_SAMPLES = 480;   // 10ms

    localparam GATE_ON_SAMPLES     = 1200; // well into sustain before releasing
    localparam RETRIGGER_SAMPLE    = GATE_ON_SAMPLES + 200; // mid-release (release is 480 samples)
    localparam TOTAL_SAMPLES       = RETRIGGER_SAMPLE + 600; // margin to observe the re-attack ramp

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

    initial begin
        fd = $fopen("envelope_retrigger.txt", "w");

        rst_n = 0;
        #100;
        rst_n <= 1;
        gate <= 1;

        while (sample_count < TOTAL_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                if (sample_count == GATE_ON_SAMPLES) gate <= 0;
                if (sample_count == RETRIGGER_SAMPLE) gate <= 1;
                $fdisplay(fd, "%d", envelope);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("RETRIGGER_ACCEPTANCE: wrote %0d envelope samples", sample_count);
        $finish;
    end

endmodule
