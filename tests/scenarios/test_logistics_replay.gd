extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "2366951b369c3138eff640b9f051729264455a91f37e129d70d21847d0b6170f",
    "1c52197a01e5a25e304a30cb3349d2520a53d2eb4c303103ea38ce84a4717a9b",
    "3c928cfb2a0f120cc46bd90decb580fc9bc6a510b94ae36ab1caef0d828809e1",
    "5fa7978e0435780789c3084b0ddf60972abb151f4ed7d1b6ec5577d6db4d378e",
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
