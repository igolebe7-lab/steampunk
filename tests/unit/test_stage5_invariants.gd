extends TestCase


func run() -> Array[String]:
    _assert_pipe_heat_and_phase_change_hash()
    _assert_new_dictionary_order_is_ignored()
    _assert_invalid_stage5_state_is_rejected()
    return finish()


func _assert_pipe_heat_and_phase_change_hash() -> void:
    var state := Stage5TestFactory.scenario_state()
    var hasher := StateHasher.new()
    var initial := hasher.hash_state(state)
    Stage5TestFactory.production(state, &"boiler").heat_level = 1
    assert_true(hasher.hash_state(state) != initial, "прогрев входит в hash v5")

    var pipe_state := Stage5TestFactory.scenario_state()
    var pipe_initial := hasher.hash_state(pipe_state)
    pipe_state.utility_network.add_segment(HexCoord.new(1, 1), &"water")
    assert_true(hasher.hash_state(pipe_state) != pipe_initial, "сегмент трубы входит в hash v5")

    var phase_state := Stage5TestFactory.scenario_state()
    var phase_initial := hasher.hash_state(phase_state)
    phase_state.scenario_progress.phase = ScenarioProgressState.WARMING
    assert_true(hasher.hash_state(phase_state) != phase_initial, "фаза входит в hash v5")


func _assert_new_dictionary_order_is_ignored() -> void:
    var first := Stage5TestFactory.scenario_state()
    var second := Stage5TestFactory.scenario_state()
    first.utility_network.add_segment(HexCoord.new(1, 1), &"water")
    first.utility_network.add_segment(HexCoord.new(2, 1), &"water")
    second.utility_network.add_segment(HexCoord.new(2, 1), &"water")
    second.utility_network.add_segment(HexCoord.new(1, 1), &"water")
    second.production_states = _reversed_dictionary(second.production_states)
    assert_eq(StateHasher.new().hash_state(first), StateHasher.new().hash_state(second), "порядок новых Dictionary не влияет на v5")


func _assert_invalid_stage5_state_is_rejected() -> void:
    var heat := Stage5TestFactory.scenario_state()
    Stage5TestFactory.production(heat, &"boiler").heat_level = 6
    assert_true(InvariantChecker.new().check(heat).has(&"invalid_production_heat"), "жар ограничен диапазоном 0..5")

    var segment := Stage5TestFactory.scenario_state()
    segment.utility_network.add_segment(HexCoord.new(999, 999), &"water")
    assert_true(InvariantChecker.new().check(segment).has(&"utility_segment_out_of_bounds"), "труба вне карты отклоняется")

    var phase := Stage5TestFactory.scenario_state()
    phase.scenario_progress.phase = &"unknown"
    assert_true(InvariantChecker.new().check(phase).has(&"invalid_scenario_phase"), "неизвестная фаза отклоняется")


func _reversed_dictionary(source: Dictionary) -> Dictionary:
    var keys := source.keys()
    keys.reverse()
    var result: Dictionary = {}
    for key: Variant in keys:
        result[key] = source[key]
    return result
