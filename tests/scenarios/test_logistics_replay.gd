extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "8a19f5626873d3c7168a6a7920e4f17280e622f9f45369fba7ce95a218c8d9cd",
    "273f6d562943b99313a2b7a6322b725db356974f5a46c0503b53c7a06fba7167",
    "221d212e5699d9ae1af57915a3c6e48172a83a403455e22d64e093e705ec11ea",
    "469fcb75da574f5d469229ee2c872a8128a2617173a4514a1e5ff416e23c168c",
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
