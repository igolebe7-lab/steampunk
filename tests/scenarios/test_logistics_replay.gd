extends TestCase

const LOGISTICS_CHECKPOINTS := [
    "a541a34c79331f9563ee929edf6fbcea23921376ef1aa0f73a36deafbe08e9e2",
    "0571c1aa6852c7300e566494b1ec7f331df910f7e33fbf4c914d4c46a9fe6b4f",
    "7c07e5d6bd92c2e1c50e50a9c6eebd0d8fb2c08adc0d11aad20d3219f476eee9",
    "d8ea5785a9edb5efb19dacb400a7db508cddcbdad167de068131ac62bdc678e4",
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
        StateHasher.new().canonicalize(first.state).begins_with("v=6|"),
        "формат должен быть v6"
    )
    return finish()


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
