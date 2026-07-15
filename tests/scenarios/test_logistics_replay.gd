extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "bb54e7d3f5ecf636078bd1b4b9afff963eacea705b266db49eb05e076f846ac1",
    "73f48dff3b33da7d85c10e8c5c35e926ea2e50fe3c8bf489cbe735d005f17fa1",
    "32ab73fc8537fed051e80ceb8720d3e0e898a6ec163b24a0d8be56de231ac9c8",
    "5dd8fde887b35cc0af3c02e7a9860590014c2c36287103e941149fcc0373bc85",
]


func run() -> Array[String]:
    var first := _runner()
    var second := _runner()
    var first_hashes := first.run_ticks(300)
    var second_hashes := second.run_ticks(300)
    assert_eq(first_hashes, second_hashes, "replay совпадает после каждого тика")
    assert_eq(
        [first_hashes[0], first_hashes[99], first_hashes[199], first_hashes[299]],
        LOGISTICS_CHECKPOINTS,
        "replay совпадает с golden-хэшами отдельного процесса"
    )
    assert_true(
        StateHasher.new().canonicalize(first.state).begins_with("v=4|"),
        "формат должен быть v4"
    )
    return finish()


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
