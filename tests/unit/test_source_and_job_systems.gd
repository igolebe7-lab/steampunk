extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var source_system := SourceSystem.new()
    for tick in range(1, 11):
        source_system.run(state, tick)
    assert_eq(state.generated_totals.get(&"wood", 0), 2, "два источника создают две единицы")
    JobSystem.new().run(state, 10)
    assert_eq(state.jobs.size(), 2, "создаются два задания")
    JobSystem.new().run(state, 10)
    assert_eq(state.jobs.size(), 2, "зарезервированный груз не дублируется")
    for job in state.jobs.values():
        assert_eq(state.get_building(job.source_id).get_outgoing_reserved(&"wood"), 1, "груз источника резервируется")
    return finish()
