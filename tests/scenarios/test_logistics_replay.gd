extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "e9a057a6a13b3edf31b42a7b67996828e7747476fb99eec0c5b47187fb9c6f00",
    "e2ea0d34717a81f94ebd5e5d5baa4f16310c750ec1b6a5136ccd453ae15b5c2d",
    "6605c8642faaef43989aa89631d47c5da3fdbec5ae9f14c09b46ddf9dd7f258d",
    "0a36d9ff0c39ef682d265c1cf8ca62da6122777827ada9550543a8a3e2b3972e",
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
