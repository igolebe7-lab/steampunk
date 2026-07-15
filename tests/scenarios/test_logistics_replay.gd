extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "2a5745e646abdef144496926bdda94747aab4ad04f1125e57023d8879861ceaf",
    "c9ebb695dda40e7a8552183d483a0a467ed72f37cb40f5cda6742d1cb62d42a6",
    "a9b666bb179af4c10585f67bcc780d53ddd6337f03556a5be8066129d69ce0a4",
    "089ec3fb956e76ebe7f448b94c85bdf460a19db7ba792ee7aa729387d9ac2904",
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
