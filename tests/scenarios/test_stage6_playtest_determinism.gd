extends TestCase


func run() -> Array[String]:
    var baseline := Stage5TestFactory.full_runner(true)
    var observed := Stage5TestFactory.full_runner(true)
    var session := PlaytestSession.new("PT-DET", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, func() -> int: return observed.state.tick * 100)

    for _index in 1000:
        var baseline_hash := baseline.step()
        var observed_hash := observed.step()
        recorder.capture_state(observed.state)
        assert_eq(observed_hash, baseline_hash, "recorder не меняет хеш тика")

    assert_eq(
        StateHasher.new().hash_state(observed.state),
        StateHasher.new().hash_state(baseline.state),
        "итоговые состояния совпадают"
    )
    assert_true(session.entries.size() > 0, "внешняя временная шкала заполнена")
    return finish()
