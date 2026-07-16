extends TestCase


func run() -> Array[String]:
    var session := PlaytestSession.new("PT-AN", "dev", 0)
    session.append(0, 0, &"state", &"flow_sample", {
        &"diagnostic_code": &"worker_shortage",
        &"main_throughput_per_minute": {&"wood": 2.0},
        &"link_throughput_per_minute": {2: 2.0},
        &"manual_water": 0,
        &"pipe_water": 0,
    })
    session.append(60_000, 600, &"command", &"link_settings", {
        &"result": &"accepted",
        &"link_id": 2,
    })
    session.append(70_000, 700, &"state", &"diagnostic_changed", {&"code": &""})
    session.append(95_000, 950, &"state", &"flow_sample", {
        &"diagnostic_code": &"",
        &"main_throughput_per_minute": {&"wood": 4.0},
        &"link_throughput_per_minute": {2: 4.0},
        &"manual_water": 1,
        &"pipe_water": 8,
    })
    session.append(130_500, 1200, &"ui", &"selection", {&"kind": &"building"})
    session.append(140_000, 1300, &"state", &"scenario_phase_changed", {
        &"phase": &"completed",
    })
    session.finish(&"completed", 140_000, 1300)

    assert_eq(session.entries[1].code, &"link_settings", "код команды сохранён")
    assert_eq(session.entries[1].category, &"command", "категория команды сохранена")
    assert_eq(session.entries[1].payload.get("result"), "accepted", "результат команды сохранён")
    assert_true(
        session.entries[1].code in PlaytestMilestoneAnalyzer.LOGISTICS_ACTIONS,
        "команда входит в список логистических действий"
    )
    var result := PlaytestMilestoneAnalyzer.new().analyze(session)
    assert_eq(
        result["milestones"]["first_logistics_action_ms"],
        60_000,
        "первая логистическая команда найдена"
    )
    assert_eq(result["water_path"], "mixed", "смешанная вода определена")
    assert_eq(result["command_counts"]["accepted"], 1, "команда учтена")
    assert_eq(
        result["bottleneck_candidates"].size(),
        1,
        "улучшение связи стало кандидатом"
    )
    assert_true(result["idle_periods"].size() >= 1, "интервал больше 30 секунд найден")
    return finish()
