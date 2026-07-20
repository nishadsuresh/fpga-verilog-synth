// tb_synth_top.v — end-to-end integration test. Sends a real MIDI note-on/
// note-off over a simulated UART line into synth_top's midi_rx pin (same
// technique as tb_melody.v) and captures the resulting audio_sample stream
// -- this is the first test that exercises synth_top.v's actual wiring
// (uart_midi -> note_lut -> nco -> adsr -> mixer), rather than testing each
// module in isolation.

`timescale 1ns / 1ps

module tb_synth_top;

    localparam CLK_FREQ_HZ    = 100_000_000;
    localparam SAMPLE_RATE_HZ = 48_000;
    localparam BAUD_RATE      = 31_250;
    localparam BIT_PERIOD_NS  = 1_000_000_000 / BAUD_RATE;

    localparam NOTE = 7'd60;          // C4, 261.63 Hz
    localparam NOTE_HOLD_SAMPLES = 4800;   // 100ms
    localparam RELEASE_SAMPLES   = 960;    // 20ms, matches synth_top's default
    localparam TOTAL_SAMPLES = NOTE_HOLD_SAMPLES + RELEASE_SAMPLES + 400; // + tail margin

    reg clk = 0;
    reg rst_n = 0;
    reg midi_rx = 1'b1; // idle high

    wire signed [15:0] audio_sample;
    wire sample_tick;

    synth_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SAMPLE_RATE_HZ(SAMPLE_RATE_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk), .rst_n(rst_n), .midi_rx(midi_rx),
        .audio_sample(audio_sample), .sample_tick(sample_tick)
    );

    always #5 clk = ~clk; // 100MHz

    // ---------------- UART byte/message sender (matches tb_melody.v) ----------------
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

    localparam NOTE_HOLD_NS = NOTE_HOLD_SAMPLES * (1_000_000_000 / SAMPLE_RATE_HZ);

    initial begin
        midi_rx = 1'b1;
        rst_n = 0;
        #100;
        rst_n = 1;
        #200;
        send_note_on(NOTE);
        #(NOTE_HOLD_NS - 3 * 10 * BIT_PERIOD_NS); // account for the 3-byte send time already elapsed
        send_note_off(NOTE);
    end

    // ---------------- audio capture ----------------
    integer fd;
    integer sample_count = 0;

    initial begin
        $dumpfile("tb_synth_top.vcd");
        $dumpvars(2, tb_synth_top);

        fd = $fopen("samples.txt", "w");
        if (fd == 0) begin
            $display("ERROR: could not open samples.txt for writing");
            $finish;
        end

        while (sample_count < TOTAL_SAMPLES) begin
            @(posedge clk);
            if (sample_tick) begin
                $fdisplay(fd, "%d", audio_sample);
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("SYNTH_TOP_ACCEPTANCE: wrote %0d samples to samples.txt", sample_count);
        $finish;
    end

endmodule
