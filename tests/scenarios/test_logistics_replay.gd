extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "a00e26ba4e126acca395fc3258e154899e549358140b9dfc208f51e4d6a04951",
    "417b5c0e0c68a7aea0ab608562b012716249dca3f82bfb9e8b719fae94bab2d0",
    "6f3e6d01f090746877bfc6389387001dd077576dff4c7a2be76abc61918dfe88",
    "03d77f0192c5f15224ac4f93383cb43642d7d86dc14f76a409b518f597a4a2e1",
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
        StateHasher.new().canonicalize(first.state).begins_with("v=5|"),
        "формат должен быть v5"
    )
    return finish()


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
