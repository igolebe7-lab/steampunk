extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "33e797fa93dfd52ab110ee79e99beee327a40b1c38b144d625bb9e31985ee9b9",
    "6b789245d5066f60fb53f2ecebb4b11ac4a16a1033ae0779f2b89fd3b21f5838",
    "6dcc5a43402c071feeaeefad13540bf77ba9bdb8b72ebccd9e606247b8402a20",
    "222a838dbe1096707062490abfb04bdfe7d7bc3161c601a667c329ff650a7a11",
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
