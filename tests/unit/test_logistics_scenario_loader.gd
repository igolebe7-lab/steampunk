extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var loaded := ScenarioLoader.new().load_scenario(scenario)
    assert_true(loaded.is_success(), "сценарий должен создавать состояние")
    if loaded.state == null:
        return finish()
    assert_eq(loaded.state.workers.size(), 6, "создаются шесть workers")
    assert_eq(loaded.state.delivery_flows.size(), 2, "разрешаются два flows")
    assert_eq(loaded.state.worker_occupancy.size(), 6, "стартовые клетки заняты")
    assert_eq(loaded.state.next_job_id, 1, "первый заказ должен получить ID 1")

    var invalid := scenario.duplicate(true) as ScenarioDef
    invalid.initial_workers[1].offset_coord = invalid.initial_workers[0].offset_coord
    var rejected := ScenarioLoader.new().load_scenario(invalid)
    assert_true(rejected.errors.has(&"worker_overlap"), "overlap должен отклоняться")
    assert_eq(rejected.state, null, "ошибка не возвращает частичное состояние")
    return finish()
