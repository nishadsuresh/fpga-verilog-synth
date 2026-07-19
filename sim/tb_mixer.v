// tb_mixer.v — standalone unit test for mixer.v with known input/output pairs,
// checked before ever embedding it in the full polyphony test (cheaper to
// debug in isolation).

`timescale 1ns/1ps

module tb_mixer;

    reg signed [15:0] s0, s1, s2, s3;
    reg [15:0] e0, e1, e2, e3;
    wire signed [15:0] mixed;

    mixer dut (
        .voice0_sample(s0), .voice0_env(e0),
        .voice1_sample(s1), .voice1_env(e1),
        .voice2_sample(s2), .voice2_env(e2),
        .voice3_sample(s3), .voice3_env(e3),
        .mixed_out(mixed)
    );

    integer errors = 0;

    task check(input signed [15:0] expected, input signed [15:0] actual, input [255:0] label);
        begin
            if (actual < expected - 2 || actual > expected + 2) begin  // +/-2 tolerance for integer rounding
                $display("  FAIL %0s: expected ~%0d, got %0d", label, expected, actual);
                errors = errors + 1;
            end else begin
                $display("  PASS %0s: expected ~%0d, got %0d", label, expected, actual);
            end
        end
    endtask

    initial begin
        // case 1: all envelopes 0 -> silence
        s0=32767; s1=32767; s2=32767; s3=32767;
        e0=0; e1=0; e2=0; e3=0;
        #10;
        check(0, mixed, "all-envelopes-zero");

        // case 2: single voice full-scale, others silent -> attenuated by headroom (~1/4)
        s0=32767; s1=0; s2=0; s3=0;
        e0=65535; e1=0; e2=0; e3=0;
        #10;
        check(32767/4, mixed, "single-voice-full-scale");

        // case 3: all 4 voices full-scale positive -> should reach full scale, no overflow
        s0=32767; s1=32767; s2=32767; s3=32767;
        e0=65535; e1=65535; e2=65535; e3=65535;
        #10;
        check(32767, mixed, "four-voices-full-scale-positive");

        // case 4: all 4 voices full-scale negative -> should reach full negative scale, no overflow/wrap
        s0=-32768; s1=-32768; s2=-32768; s3=-32768;
        e0=65535; e1=65535; e2=65535; e3=65535;
        #10;
        check(-32768, mixed, "four-voices-full-scale-negative");

        // case 5: half envelope on one voice
        s0=32767; s1=0; s2=0; s3=0;
        e0=32768; e1=0; e2=0; e3=0;
        #10;
        check(32767/8, mixed, "half-envelope-single-voice");

        $display("\nMIXER_UNIT_TEST: %0d errors", errors);
        if (errors == 0) $display("MIXER_UNIT_TEST_RESULT: PASS");
        else $display("MIXER_UNIT_TEST_RESULT: FAIL");
        $finish;
    end

endmodule
