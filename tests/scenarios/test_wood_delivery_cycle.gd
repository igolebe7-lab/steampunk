extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var runner := SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
    runner.run_ticks(600)
    assert_true(runner.state.delivered_totals.get(&"wood", 0) >= 12, "завершаются минимум 12 доставок")
    assert_eq(
        _wood_in_world(runner.state),
        runner.state.generated_totals.get(&"wood", 0),
        "древесина сохраняется"
    )
    return finish()


func _wood_in_world(state: SimulationState) -> int:
    var total := 0
    for value: Variant in state.buildings.values():
        total += (value as BuildingState).get_amount(&"wood")
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        total += 1 if worker.cargo_resource_id == &"wood" else 0
    return total
