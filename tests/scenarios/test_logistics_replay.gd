extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "2b805e1f4c60d8041d006c593ad8380d4750ba684c5ca23ccde5130526144b97",
    "47a93e00fa8a74fcbaa443a5d1d959e8098122d2a59175325b1f9a08541b4168",
    "ab7735997ac07456608393944c360337dce8983e9002c520630d41364ad4f1a6",
    "4117f19b0add14b2ed5c74ea25eb5970602a9ac72edc5ac26b94f46f72799ede",
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
