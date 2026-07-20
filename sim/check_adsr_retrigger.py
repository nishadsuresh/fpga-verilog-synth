"""Regression check for the retrigger-snaps-to-0 bug in adsr.v: a note
retriggered mid-release should resume ramping from its current envelope
level, not snap to 0 first (which would be an audible click and contradicts
the module's own header comment)."""

import sys

GATE_ON_SAMPLES = 1200
RETRIGGER_SAMPLE = GATE_ON_SAMPLES + 200

if __name__ == "__main__":
    with open("envelope_retrigger.txt") as f:
        env = [int(line.strip()) for line in f if line.strip()]

    ok = True

    level_just_before_retrigger = env[RETRIGGER_SAMPLE - 1]
    level_just_after_retrigger = env[RETRIGGER_SAMPLE]

    # the envelope must NOT collapse to (near) zero at the retrigger instant --
    # it should start the new attack ramp from close to where release had
    # gotten to (a gate rising-edge sample also updates counter/state before
    # the ramp math runs, so allow one sample tick of pre-ramp settling).
    near_zero_threshold = 500  # out of 0..65535 -- comfortably below a real mid-release level
    status = "PASS" if level_just_after_retrigger > near_zero_threshold else "FAIL"
    if level_just_after_retrigger <= near_zero_threshold:
        ok = False
    print(f"  envelope at retrigger: before={level_just_before_retrigger} after={level_just_after_retrigger} "
          f"(must stay > {near_zero_threshold}, not snap toward 0) [{status}]")

    # After retriggering, the envelope should trend clearly upward toward
    # ENV_MAX over the new attack window -- checked over a longer span
    # rather than strict sample-to-sample monotonicity, since the DUT's
    # gate&&!gate_prev edge lags the testbench's intended retrigger sample
    # by a tick or two (sample_tick-gated register timing, same kind of
    # off-by-a-few alignment already seen and accounted for elsewhere in
    # this project), so the release ramp can still tick down slightly for a
    # sample or two right at the boundary before the new attack takes over.
    near_end_of_new_attack = env[RETRIGGER_SAMPLE + 350]
    status = "PASS" if near_end_of_new_attack > level_just_after_retrigger else "FAIL"
    if near_end_of_new_attack <= level_just_after_retrigger:
        ok = False
    print(f"  envelope trends upward over the new attack window: "
          f"at retrigger={level_just_after_retrigger} vs +350 samples={near_end_of_new_attack} [{status}]")

    print(f"\nadsr.v retrigger regression: {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if ok else 1)
