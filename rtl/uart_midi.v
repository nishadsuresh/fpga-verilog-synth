// uart_midi.v — UART receiver (8-N-1) + MIDI 3-byte message parser
// (Note On = 0x9n, Note Off = 0x8n, or Note On with velocity 0 treated as
// Note Off, per the MIDI spec). Outputs the current active note and a gate
// signal suitable for driving an adsr module directly.

module uart_midi #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 31250
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,           // serial MIDI input line, idle high
    output reg  [6:0] note,         // current active MIDI note number
    output reg        gate,         // 1 while a note is sounding
    output reg        note_valid    // 1-cycle pulse when `note` changes on a new note-on
);

    localparam integer CYCLES_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    // 2-flop synchronizer: rx is an asynchronous external serial line, and
    // sampling it directly with clk (as an earlier version of this module
    // did) is a real metastability risk on actual FPGA hardware, not just a
    // simulation nicety -- everything below reads rx_sync, never raw rx.
    reg rx_meta, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1; // idle high
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    // ---------------- UART byte receiver ----------------
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0] rx_state;
    reg [15:0] cycle_counter;
    reg [2:0] bit_index;
    reg [7:0] rx_shift;
    reg [7:0] rx_byte;
    reg rx_byte_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            cycle_counter <= 0;
            bit_index <= 0;
            rx_byte_valid <= 1'b0;
        end else begin
            rx_byte_valid <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync) begin // start bit detected
                        rx_state <= RX_START;
                        cycle_counter <= 0;
                    end
                end
                RX_START: begin
                    if (cycle_counter == (CYCLES_PER_BIT / 2)) begin // sample mid-start-bit to confirm
                        if (!rx_sync) begin
                            rx_state <= RX_DATA;
                            cycle_counter <= 0;
                            bit_index <= 0;
                        end else begin
                            rx_state <= RX_IDLE; // false start
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                RX_DATA: begin
                    if (cycle_counter == CYCLES_PER_BIT - 1) begin
                        cycle_counter <= 0;
                        rx_shift <= {rx_sync, rx_shift[7:1]}; // LSB first
                        if (bit_index == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                RX_STOP: begin
                    if (cycle_counter == CYCLES_PER_BIT - 1) begin
                        cycle_counter <= 0;
                        rx_state <= RX_IDLE;
                        if (rx_sync) begin // valid stop bit
                            rx_byte <= rx_shift;
                            rx_byte_valid <= 1'b1;
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

    // ---------------- MIDI 3-byte message assembler ----------------
    // Scope: assumes every status byte is followed by exactly 2 data bytes
    // (true for Note On/Off, this module's only supported message types).
    // Any other MIDI message type (Program Change, realtime bytes, etc.)
    // will desync the assembler, since it has no way to know how many data
    // bytes a status byte it doesn't recognize is supposed to carry.
    localparam MSG_WAIT_STATUS = 2'd0;
    localparam MSG_WAIT_DATA1  = 2'd1;
    localparam MSG_WAIT_DATA2  = 2'd2;

    reg [1:0] msg_state;
    reg [7:0] status_byte;
    reg [7:0] data1_byte;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg_state <= MSG_WAIT_STATUS;
            note <= 7'd0;
            gate <= 1'b0;
            note_valid <= 1'b0;
        end else begin
            note_valid <= 1'b0;
            if (rx_byte_valid) begin
                case (msg_state)
                    MSG_WAIT_STATUS: begin
                        if (rx_byte[7] == 1'b1) begin // status bytes have MSB set
                            status_byte <= rx_byte;
                            msg_state <= MSG_WAIT_DATA1;
                        end
                    end
                    MSG_WAIT_DATA1: begin
                        data1_byte <= rx_byte;
                        msg_state <= MSG_WAIT_DATA2;
                    end
                    MSG_WAIT_DATA2: begin
                        // status_byte[7:4]: 9=note-on, 8=note-off. data1=note, data2=velocity.
                        if (status_byte[7:4] == 4'h9 && rx_byte != 8'd0) begin
                            note <= data1_byte[6:0];
                            gate <= 1'b1;
                            note_valid <= 1'b1;
                        end else if (status_byte[7:4] == 4'h8 || (status_byte[7:4] == 4'h9 && rx_byte == 8'd0)) begin
                            // note-off, or note-on with velocity 0 (running-status idiom)
                            if (data1_byte[6:0] == note) gate <= 1'b0;
                        end
                        msg_state <= MSG_WAIT_STATUS;
                    end
                    default: msg_state <= MSG_WAIT_STATUS;
                endcase
            end
        end
    end

endmodule
