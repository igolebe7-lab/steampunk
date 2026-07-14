extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var ids: Array = state.workers.keys()
    ids.sort()
    state.get_worker(ids[1]).coord = state.get_worker(ids[0]).coord
    assert_true(InvariantChecker.new().check(state).has(&"worker_overlap"), "overlap обнаруживается")

    var clean := ScenarioLoader.new().load_scenario(scenario).state
    clean.generated_totals[&"wood"] = 1
    assert_true(
        InvariantChecker.new().check(clean).has(&"resource_conservation"),
        "потеря груза обнаруживается"
    )
    return finish()
