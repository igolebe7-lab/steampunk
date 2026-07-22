extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var loaded := ScenarioLoader.new().load_scenario(scenario)
    assert_true(loaded.is_success(), "сценарий должен создавать состояние")
    if loaded.state == null:
        return finish()
    assert_eq(loaded.state.workers.size(), 6, "создаются шесть workers")
    assert_eq(loaded.state.delivery_flows.size(), 0, "flows не остаются runtime-состоянием")
    assert_eq(loaded.state.logistics_links.size(), 2, "два flows конвертируются в links")
    assert_eq(loaded.state.next_job_id, 1, "первый заказ должен получить ID 1")

    var invalid := scenario.duplicate(true) as ScenarioDef
    invalid.initial_workers[1].offset_coord = invalid.initial_workers[0].offset_coord
    var overlapping := ScenarioLoader.new().load_scenario(invalid)
    assert_true(overlapping.is_success(), "начальные носильщики могут находиться в одной клетке")
    if overlapping.state != null:
        var overlapping_ids: Array = overlapping.state.workers.keys()
        overlapping_ids.sort()
        assert_true(
            overlapping.state.get_worker(overlapping_ids[0]).coord.equals(
                overlapping.state.get_worker(overlapping_ids[1]).coord
            ),
            "loader сохраняет общую стартовую клетку"
        )

    var invalid_timing := scenario.duplicate(true) as ScenarioDef
    invalid_timing.worker_ticks_per_hex = 0
    var timing_result := ScenarioLoader.new().load_scenario(invalid_timing)
    assert_true(
        timing_result.errors.has(&"invalid_simulation_timing"),
        "нулевой timing должен отклоняться до создания состояния"
    )
    assert_eq(timing_result.state, null, "невалидный timing не возвращает состояние")

    var invalid_priority := scenario.duplicate(true) as ScenarioDef
    invalid_priority.delivery_flows[0].priority = 5
    var priority_result := ScenarioLoader.new().load_scenario(invalid_priority)
    assert_true(
        priority_result.errors.has(&"invalid_flow_priority"),
        "priority потока вне диапазона должен отклоняться"
    )

    var invalid_source := scenario.duplicate(true) as ScenarioDef
    invalid_source.delivery_flows[0].source_key = &"depot"
    invalid_source.delivery_flows[0].destination_key = &"source_west"
    var source_result := ScenarioLoader.new().load_scenario(invalid_source)
    assert_true(
        source_result.errors.has(&"invalid_flow_source"),
        "поток должен начинаться в совместимом источнике"
    )
    return finish()
