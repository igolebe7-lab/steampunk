extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "a6a281eccaefd1fe7853d3ba178846fb03cc9feb69aa4a63ec2db6abf5d62219",
    "3a088f2923aa6e366c798e6b996bffef80c64ad976345834c190e97732dfcb5c",
    "2e5ef91648e02235e2bde2cf386390897dc3860e5db70e914d5fe884302d2466",
    "d4712851628889fa5364e39a0d3380db675b6c662aadc6d8eec0be1cad4bfc61",
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
        StateHasher.new().canonicalize(first.state).begins_with("v=3|"),
        "формат должен быть v3"
    )
    return finish()


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
