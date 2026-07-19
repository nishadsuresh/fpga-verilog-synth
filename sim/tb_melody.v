// tb_melody.v — Phase 5 testbench. Sends a real MIDI byte stream over a
// simulated UART line (C4-D4-E4-D4-C4), driving uart_midi -> note_lut -> nco
// -> adsr -> straight to output (no mixer needed for a single voice). The
// UART sender and the audio-sample capture run as two concurrent processes:
// UART timing is real (wall-clock-style delays at the 31250 baud bit rate),
// audio capture is sample_tick-driven, exactly like a real receiver would see it.

`timescale 1ns / 1ps

module tb_melody;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;
    localparam BAUD_RATE      = 31_250;
    localparam BIT_PERIOD_NS  = 1_000_000_000 / BAUD_RATE; // 32000ns

    localparam [23:0] ATTACK_SAMPLES  = 240;  // 5ms
    localparam [23:0] DECAY_SAMPLES   = 240;  // 5ms
    localparam [15:0] SUSTAIN_LEVEL   = 55000;
    localparam [23:0] RELEASE_SAMPLES = 960;  // 20ms

    localparam NOTE_HOLD_SAMPLES = 4800; // 100ms per note
    localparam N_NOTES = 5;
    localparam TOTAL_SAMPLES = NOTE_HOLD_SAMPLES * N_NOTES + RELEASE_SAMPLES + 400; // + tail margin

    reg clk = 0;
    reg rst_n = 0;
    reg sample_tick = 0;
    reg midi_rx = 1'b1; // idle high

    wire [6:0] note;
    wire gate;
    wire note_valid;
    wire [31:0] phase_inc;
    wire signed [15:0] nco_out;
    wire [15:0] env;
    wire signed [15:0] voice_out;

    uart_midi #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) midi_rx_dut (
        .clk(clk), .rst_n(rst_n), .rx(midi_rx), .note(note), .gate(gate), .note_valid(note_valid)
    );

    note_lut lut (.midi_note(note), .phase_increment(phase_inc));

    nco nco_dut (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .phase_increment(phase_inc), .sample_out(nco_out));

    adsr adsr_dut (.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate),
        .attack_samples(ATTACK_SAMPLES), .decay_samples(DECAY_SAMPLES),
        .sustain_level(SUSTAIN_LEVEL), .release_samples(RELEASE_SAMPLES), .envelope(env));

    // scale nco_out by envelope directly (no mixer needed for a single voice)
    wire signed [31:0] scaled = nco_out * $signed({1'b0, env});
    assign voice_out = scaled >>> 16;

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

    // ---------------- UART byte/message sender ----------------
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            midi_rx = 1'b0; // start bit
            #BIT_PERIOD_NS;
            for (i = 0; i < 8; i = i + 1) begin
                midi_rx = data[i];
                #BIT_PERIOD_NS;
            end
            midi_rx = 1'b1; // stop bit
            #BIT_PERIOD_NS;
        end
    endtask

    task send_note_on(input [6:0] n);
        begin
            send_uart_byte(8'h90);
            send_uart_byte({1'b0, n});
            send_uart_byte(8'd100); // velocity
        end
    endtask

    task send_note_off(input [6:0] n);
        begin
            send_uart_byte(8'h80);
            send_uart_byte({1'b0, n});
            send_uart_byte(8'd0);
        end
    endtask

    localparam NOTE_HOLD_NS = NOTE_HOLD_SAMPLES * (1_000_000_000 / SAMPLE_RATE_HZ); // 100ms in ns

    reg [6:0] melody [0:N_NOTES-1];
    initial begin
        melody[0] = 7'd60; melody[1] = 7'd62; melody[2] = 7'd64; melody[3] = 7'd62; melody[4] = 7'd60;
    end

    integer m;
    initial begin
        midi_rx = 1'b1;
        #200; // wait past reset
        for (m = 0; m < N_NOTES; m = m + 1) begin
            send_note_on(melody[m]);
            #(NOTE_HOLD_NS - 3 * 10 * BIT_PERIOD_NS); // hold for the rest of this note's window (message send time already elapsed)
            send_note_off(melody[m]);
        end
    end

    // ---------------- audio capture ----------------
    integer fd;
    integer sample_count = 0;

    initial begin
        $dumpfile("tb_melody.vcd");
        // depth 2 (not 0/unlimited) -- this testbench's 528ms duration combined
        // with recursing into nco's 1024-entry sine LUT array produced a 2.5GB
        // VCD; top-level signals are enough for GTKWave inspection of gate/note/envelope.
        $dumpvars(2, tb_melody);

        fd = $fopen("samples_melody.txt", "w");

        rst_n = 0;
        #100;
        rst_n = 1;

        while (sample_count < TOTAL_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                $fdisplay(fd, "%d", voice_out);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("PHASE5_ACCEPTANCE: wrote %0d samples", sample_count);
        $finish;
    end

endmodule
