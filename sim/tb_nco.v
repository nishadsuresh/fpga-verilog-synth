// tb_nco.v — Phase 2 testbench. Three parallel NCO instances at A2 (110Hz),
// A4 (440Hz), A6 (1760Hz), each rendered to its own samples file. A Python
// FFT check (sim/check_pitch.py) verifies each is within 5 cents of target.

`timescale 1ns / 1ps

module tb_nco;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;
    localparam N_SAMPLES      = 24_000;  // 0.5s per note — plenty for parabolic-interpolated FFT peak finding

    // phase_increment = round(freq * 2^32 / sample_rate) — verified via Python, not hand-calculated
    localparam [31:0] PHASE_INC_A2 = 32'd9842633;    // 110 Hz
    localparam [31:0] PHASE_INC_A4 = 32'd39370534;   // 440 Hz
    localparam [31:0] PHASE_INC_A6 = 32'd157482134;  // 1760 Hz

    reg clk = 0;
    reg rst_n = 0;
    reg sample_tick = 0;

    wire signed [15:0] out_a2, out_a4, out_a6;

    nco nco_a2 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_A2), .sample_out(out_a2));
    nco nco_a4 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_A4), .sample_out(out_a4));
    nco nco_a6 (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(PHASE_INC_A6), .sample_out(out_a6));

    always #5 clk = ~clk;  // 100MHz

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

    integer fd_a2, fd_a4, fd_a6;
    integer sample_count = 0;

    initial begin
        $dumpfile("tb_nco.vcd");
        $dumpvars(0, tb_nco);

        fd_a2 = $fopen("samples_a2.txt", "w");
        fd_a4 = $fopen("samples_a4.txt", "w");
        fd_a6 = $fopen("samples_a6.txt", "w");

        rst_n = 0;
        #100;
        rst_n = 1;

        while (sample_count < N_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                $fdisplay(fd_a2, "%d", out_a2);
                $fdisplay(fd_a4, "%d", out_a4);
                $fdisplay(fd_a6, "%d", out_a6);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd_a2);
        $fclose(fd_a4);
        $fclose(fd_a6);
        $display("PHASE2_ACCEPTANCE: wrote %0d samples per note (A2/A4/A6)", sample_count);
        $finish;
    end

endmodule
