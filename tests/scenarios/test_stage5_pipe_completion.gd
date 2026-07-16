extends TestCase


func run() -> Array[String]:
    var result := Stage5TestFactory.run_full_scenario(true, 12000)
    var state := result.get(&"state") as SimulationState
    print("STAGE5_PIPE ticks=%d pipe_water=%d manual_water=%d" % [result.get(&"ticks", 0), state.utility_network.pipe_water_delivered, state.utility_network.manual_water_delivered])
    assert_true(result.get(&"pipe_built", false) as bool, "труба построена из реально доставленного железа")
    assert_eq(state.scenario_progress.phase, ScenarioProgressState.COMPLETED, "сценарий завершается с трубопроводом")
    assert_eq(state.scenario_progress.hammer_strikes, 1, "трубный маршрут даёт ровно один удар")
    assert_true(state.utility_network.pipe_water_delivered > 0, "котёл получает воду по трубе")
    assert_true((result.get(&"ticks", 0) as int) <= 12000, "трубный маршрут укладывается в предел сценария")
    assert_true(InvariantChecker.new().check(state).is_empty(), "трубный финал сохраняет ресурсы и инварианты")
    return finish()
