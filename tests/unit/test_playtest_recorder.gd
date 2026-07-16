extends TestCase


func run() -> Array[String]:
    var now := [1000]
    var clock := func() -> int: return now[0] as int
    var session := PlaytestSession.new("PT-REC", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, clock)
    var state := Stage5TestFactory.scenario_state()

    recorder.record_action(state.tick, &"ui", &"selection", {&"kind": &"building"})
    now[0] = 2100
    recorder.record_command(state, &"link_settings", &"accepted", {&"link_id": 2})

    state.tick = 100
    state.diagnostic_report = DiagnosticReport.new(&"worker_shortage", 10, 2)
    var delivered := SimulationEvent.new(&"cargo_delivered", 100, 1, 9, &"wood")
    delivered.link_id = 2
    state.events = [delivered]
    recorder.capture_state(state)

    state.tick = 200
    state.scenario_progress.phase = ScenarioProgressState.SITE_PREPARATION
    state.events = []
    recorder.capture_state(state)

    var codes: Array[String] = []
    for entry: PlaytestEntry in session.entries:
        codes.append(String(entry.code))
    assert_true(codes.has("selection"), "выбор записан")
    assert_true(codes.has("link_settings"), "результат команды записан")
    assert_true(codes.has("diagnostic_changed"), "смена диагностики записана")
    assert_true(codes.has("cargo_delivered"), "значимое событие симуляции записано")
    assert_true(codes.has("flow_sample"), "снимок потока записан раз в 100 тиков")
    assert_true(codes.has("scenario_phase_changed"), "смена фазы записана по состоянию")
    assert_true(session.entries.size() < 20, "recorder не пишет каждый тик")
    return finish()
