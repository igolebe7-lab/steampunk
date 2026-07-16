extends TestCase


func run() -> Array[String]:
    var result := Stage5TestFactory.run_full_scenario(false, 12000)
    var state := result.get(&"state") as SimulationState
    print("STAGE5_MANUAL ticks=%d manual_water=%d" % [result.get(&"ticks", 0), state.utility_network.manual_water_delivered])
    assert_eq(state.scenario_progress.phase, ScenarioProgressState.COMPLETED, "сценарий завершается с водой в бочках")
    assert_eq(state.scenario_progress.hammer_strikes, 1, "ручной маршрут даёт ровно один удар")
    assert_eq(state.utility_network.pipe_water_delivered, 0, "ручной маршрут не получает скрытую трубную воду")
    assert_true((result.get(&"ticks", 0) as int) <= 12000, "ручной маршрут укладывается в предел сценария")
    assert_true(InvariantChecker.new().check(state).is_empty(), "ручной финал сохраняет ресурсы и инварианты")
    return finish()
