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
    _assert_source_respects_incoming_capacity(scenario)
    return finish()


func _assert_source_respects_incoming_capacity(scenario: ScenarioDef) -> void:
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var source := state.get_building((state.logistics_links[1] as LogisticsLinkState).source_id)
    source.add_amount(&"wood", 7)
    source.reserve_incoming(&"wood", 1)
    source.source_progress_ticks = 9
    SourceSystem.new().run(state, 10)
    assert_eq(
        source.get_amount(&"wood"),
        7,
        "источник не занимает место, обещанное incoming reservation"
    )
