extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var first := ScenarioLoader.new().load_scenario(scenario).state
    var second := ScenarioLoader.new().load_scenario(scenario).state
    assert_true(first != null and second != null, "хэшеру требуются два загруженных состояния")
    if first == null or second == null:
        return finish()

    var hasher := StateHasher.new()
    assert_eq(
        hasher.canonicalize(first),
        hasher.canonicalize(second),
        "одинаковые состояния должны иметь одинаковое каноническое представление"
    )
    var initial_hash := hasher.hash_state(first)
    assert_eq(initial_hash.length(), 64, "SHA-256 должен содержать 64 шестнадцатеричных символа")
    assert_eq(initial_hash, hasher.hash_state(second), "одинаковые состояния должны иметь одинаковый хэш")

    var reordered: Dictionary = {}
    for id in [3, 2, 1]:
        reordered[id] = second.buildings[id]
    second.buildings = reordered
    assert_eq(initial_hash, hasher.hash_state(second), "порядок Dictionary не должен влиять на хэш")

    second.get_building(1).priority = 4
    assert_true(initial_hash != hasher.hash_state(second), "изменение состояния должно менять хэш")

    var changed_map := ScenarioLoader.new().load_scenario(scenario).state
    var first_cell := changed_map.map_state.get_cells()[0]
    changed_map.map_state.set_movement_cost(first_cell.coord, 2)
    assert_true(
        initial_hash != hasher.hash_state(changed_map),
        "изменение клетки карты должно менять хэш состояния"
    )
    return finish()
