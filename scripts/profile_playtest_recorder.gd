extends SceneTree

const PAIR_COUNT := 5
const TICK_COUNT := 2000
const MAX_OVERHEAD := 1.03


func _initialize() -> void:
    call_deferred("_run_profile")


func _run_profile() -> void:
    var baseline_samples: Array[int] = []
    var recorder_samples: Array[int] = []
    for pair_index in PAIR_COUNT:
        if pair_index % 2 == 0:
            baseline_samples.append(_measure(false))
            recorder_samples.append(_measure(true))
        else:
            recorder_samples.append(_measure(true))
            baseline_samples.append(_measure(false))
    baseline_samples.sort()
    recorder_samples.sort()
    var baseline_ms := maxi(baseline_samples[PAIR_COUNT / 2] / 1000, 1)
    var recorder_ms := maxi(recorder_samples[PAIR_COUNT / 2] / 1000, 1)
    var overhead := float(recorder_ms) / maxf(float(baseline_ms), 1.0)
    print(
        "STAGE6_RECORDER baseline_ms=%d recorder_ms=%d overhead=%.4f"
        % [baseline_ms, recorder_ms, overhead]
    )
    quit(1 if overhead > MAX_OVERHEAD else 0)


func _measure(with_recorder: bool) -> int:
    var runner := Stage5TestFactory.full_runner(false)
    var recorder: PlaytestRecorder
    if with_recorder:
        var session := PlaytestSession.new("PT-PROFILE", "dev", 0)
        recorder = PlaytestRecorder.new()
        recorder.configure(
            session,
            func() -> int: return runner.state.tick * 100
        )
    var started_usec := Time.get_ticks_usec()
    for _tick in TICK_COUNT:
        runner.step()
        if recorder != null:
            recorder.capture_state(runner.state)
    return Time.get_ticks_usec() - started_usec
