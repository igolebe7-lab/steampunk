extends TestCase


func run() -> Array[String]:
    _assert_bounded_window_and_warmup()
    _assert_window_metrics()
    _assert_telemetry_system_collects_events_and_load()
    _assert_inactive_production_links_do_not_report_worker_shortage()
    return finish()


func _assert_bounded_window_and_warmup() -> void:
    var window := TelemetryWindow.new()
    for tick in range(1, 100):
        window.append_sample({&"tick": tick})
    assert_true(not window.is_warm(), "99 тиков недостаточно для прогрева")
    window.append_sample({&"tick": 100})
    assert_true(window.is_warm(), "100 тиков завершают прогрев")

    for tick in range(101, 701):
        window.append_sample({&"tick": tick})
    assert_eq(window.size(), 600, "кольцевое окно ограничено 600 тиками")
    assert_eq(window.total_samples, 700, "накопительный счётчик не ограничен окном")
    assert_eq(window.oldest_tick(), 101, "окно вытесняет самый старый тик")
    assert_eq(window.latest_tick(), 700, "окно сохраняет последний тик")


func _assert_window_metrics() -> void:
    var window := TelemetryWindow.new()
    for tick in range(1, 601):
        window.append_sample({
            &"tick": tick,
            &"main_deliveries": {&"wood": 1 if tick % 60 == 0 else 0},
            &"link_deliveries": {7: 1 if tick % 120 == 0 else 0},
            &"job_latency_total": 12 if tick == 600 else 0,
            &"completed_jobs": 1 if tick == 600 else 0,
            &"moving_workers": 2,
            &"waiting_workers": 1,
            &"queue_depth": 3,
            &"link_load": {7: 2},
            &"cell_load": {&"2:3": 1},
            &"cell_conflicts": {&"2:3": 1 if tick % 10 == 0 else 0},
            &"losses": {&"route_conflict": 1 if tick % 10 == 0 else 0},
        })

    assert_near(window.main_throughput_per_minute(&"wood"), 10.0, 0.001, "main throughput измеряется в единицах/мин")
    assert_near(window.link_throughput_per_minute(7), 5.0, 0.001, "link throughput измеряется в единицах/мин")
    assert_near(window.average_job_latency_ticks(), 12.0, 0.001, "latency усредняется по завершённым job")
    assert_near(window.average_moving_workers(), 2.0, 0.001, "окно считает движение")
    assert_near(window.average_waiting_workers(), 1.0, 0.001, "окно считает ожидание")
    assert_near(window.average_queue_depth(), 3.0, 0.001, "окно считает очередь")
    assert_near(window.average_link_load(7), 2.0, 0.001, "окно считает загрузку link")
    assert_near(window.average_cell_load(&"2:3"), 1.0, 0.001, "окно считает загрузку клетки")
    assert_eq(window.cell_conflict_count(&"2:3"), 60, "окно считает конфликты клетки")
    assert_eq(window.loss_ticks(&"route_conflict"), 60, "окно хранит измеренные потери")


func _assert_telemetry_system_collects_events_and_load() -> void:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    var link_id := state.logistics_links.keys()[0] as int
    var worker := state.workers.values()[0] as WorkerState
    worker.link_id = link_id
    worker.action = WorkerState.TO_DESTINATION
    worker.wait_reason = &"cell_reserved"
    var delivered := SimulationEvent.new(&"cargo_delivered", 120, worker.id, 41, &"wood")
    delivered.link_id = link_id
    delivered.destination_id = state.main_warehouse_id
    delivered.metric_value = 20
    state.events.append(delivered)
    var conflict := SimulationEvent.new(&"worker_waiting", 120, worker.id, 41, &"wood")
    conflict.link_id = link_id
    conflict.cell_key = &"2:3"
    conflict.reason = &"cell_reserved"
    state.events.append(conflict)

    TelemetrySystem.new().run(state, 120)

    assert_eq(state.telemetry_window.latest_tick(), 120, "telemetry записывает текущий тик")
    assert_near(state.telemetry_window.main_throughput_per_minute(&"wood"), 600.0, 0.001, "delivery в main попадает в throughput")
    assert_near(state.telemetry_window.link_throughput_per_minute(link_id), 600.0, 0.001, "delivery попадает в throughput link")
    assert_near(state.telemetry_window.average_job_latency_ticks(), 20.0, 0.001, "delivery передаёт latency завершённого job")
    assert_eq(state.telemetry_window.cell_conflict_count(&"2:3"), 1, "movement conflict привязан к клетке")
    assert_near(state.telemetry_window.average_link_load(link_id), 1.0, 0.001, "назначенный worker создаёт load link")
    assert_true(not (state.telemetry.get(&"ready", true) as bool), "публичная telemetry отмечает warmup")
    DiagnosticsSystem.new().run(state)
    assert_eq(state.diagnostic_report.cell_key, &"2:3", "diagnostic report указывает целевую клетку конфликта")


func _assert_inactive_production_links_do_not_report_worker_shortage() -> void:
    var scenario := load("res://data/scenarios/full_industrial.tres") as ScenarioDef
    var loaded := ScenarioLoader.new().load_scenario(scenario)
    var runner := SimulationRunner.new(loaded.state, false)
    runner.run_ticks(100)
    var free_workers := 0
    for value: Variant in runner.state.workers.values():
        var worker := value as WorkerState
        if (
            worker.action == WorkerState.IDLE
            and worker.link_id == 0
            and worker.job_id == 0
        ):
            free_workers += 1
    assert_eq(free_workers, 2, "в фазе наблюдения два носильщика действительно свободны")
    assert_true(
        runner.state.diagnostic_report.code != &"worker_shortage",
        "заблокированное производство без спроса не создаёт ложный дефицит работников"
    )
