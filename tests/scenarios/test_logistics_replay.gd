extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "fc8d2c6d78dcc539ac9a12546c2d79b1845a70b732a599d1567220ccd24db6ad",
    "997a9867209952a09e35f84e8afb6409f4daf7a9662521c2d70a7fa3023ad6e8",
    "465843bf819b237e5c7f9117dbdae4c4fc23c83eb6f2f9388c2420e9743e9c5f",
    "5430e8dbbc1200ca5fec7cccdc1ca3acab06699aa5af7a99a91cb43f2a6f7bca",
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
