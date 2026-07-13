extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var loaded := ScenarioLoader.new().load_scenario(scenario)
    assert_true(loaded.is_success(), "тесту требуется корректное начальное состояние")
    if not loaded.is_success():
        return finish()

    var state := loaded.state
    var system := CommandSystem.new()
    var accepted := system.apply(
        state,
        SimulationCommand.set_building_priority(1, 1, 1, 4)
    )
    assert_true(accepted.accepted, "допустимая команда должна применяться")
    assert_eq(state.get_building(1).priority, 4, "команда должна изменить приоритет здания")

    var invalid_priority := system.apply(
        state,
        SimulationCommand.set_building_priority(1, 2, 1, 9)
    )
    assert_eq(invalid_priority.code, &"invalid_priority", "недопустимый приоритет должен отклоняться")
    assert_eq(state.get_building(1).priority, 4, "отклонённая команда не должна менять состояние")

    var missing_building := system.apply(
        state,
        SimulationCommand.set_building_priority(1, 3, 999, 2)
    )
    assert_eq(missing_building.code, &"unknown_building", "неизвестное здание должно отклоняться")
    assert_eq(InvariantChecker.new().check(state), [], "корректное состояние должно выполнять инварианты")
    return finish()
