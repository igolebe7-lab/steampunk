extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "35a62f6f7ac6e231d8f66b96ba2e94fc6f03ae201d76a8e97e433155ee86d037",
    "57c6b7341e5facbb3581963c67edf3d35ddbf86eab5861c9e1d994dec50e96dd",
    "74aa6772c8dc29c18fbe45cbd19b30d25ea8d8bca0af943189462483a1b3fbd3",
    "13e70b12ece5ce5b38d69192f15edb73c205e85ed80a1f2e6938f5010bc673e1",
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
