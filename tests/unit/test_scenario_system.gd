extends TestCase


func run() -> Array[String]:
    assert_true(ResourceLoader.exists("res://src/simulation/model/scenario_progress_state.gd"), "состояние прогресса сценария существует")
    assert_true(ResourceLoader.exists("res://src/simulation/systems/scenario_system.gd"), "система фаз сценария существует")
    if not ResourceLoader.exists("res://src/simulation/systems/scenario_system.gd"):
        return finish()
    _assert_phase_sequence_is_monotonic()
    return finish()


func _assert_phase_sequence_is_monotonic() -> void:
    var state := Stage5TestFactory.scenario_state()
    var system := ScenarioSystem.new()
    var hammer := Stage5TestFactory.production(state, &"steam_hammer")
    var boiler := Stage5TestFactory.production(state, &"boiler")

    system.run(state, 899)
    assert_eq(state.scenario_progress.phase, &"observation", "до 900 тиков идёт наблюдение")
    system.run(state, 900)
    assert_eq(state.scenario_progress.phase, &"site_preparation", "на 900-м тике площадка активирована")
    assert_eq(hammer.status, ProductionState.WAITING_INPUTS, "стройплощадка начинает запрашивать материалы")

    hammer.status = ProductionState.COMPLETED
    system.run(state, 901)
    assert_eq(state.scenario_progress.phase, &"boiler_supply", "после площадки разблокирован котёл")
    assert_eq(boiler.status, ProductionState.WAITING_INPUTS, "котёл начинает принимать уголь и воду")

    boiler.status = ProductionState.RUNNING
    system.run(state, 902)
    assert_eq(state.scenario_progress.phase, &"warming", "запущенный котёл переводит сценарий в прогрев")

    boiler.heat_level = 5
    system.run(state, 903)
    assert_eq(state.scenario_progress.phase, &"first_strike", "полный жар разблокирует первый удар")
    assert_eq(hammer.recipe_id, &"first_hammer_strike", "молот переключён на финальный рецепт")
    assert_eq(hammer.status, ProductionState.WAITING_INPUTS, "молот запрашивает две единицы железа")

    boiler.heat_level = 0
    system.run(state, 904)
    assert_eq(state.scenario_progress.phase, &"first_strike", "охлаждение не откатывает фазу")

    state.events.append(SimulationEvent.new(&"hammer_struck", 905, hammer.building_id))
    system.run(state, 905)
    assert_eq(state.scenario_progress.phase, &"completed", "первый удар завершает сценарий")
    assert_eq(state.scenario_progress.hammer_strikes, 1, "первый удар учитывается один раз")
    assert_eq(state.scenario_progress.final_metrics.get(&"active_ticks", 0), 5, "активное время считается после наблюдения")

    system.run(state, 906)
    assert_eq(state.scenario_progress.phase, &"completed", "завершённый сценарий не регрессирует")
    assert_eq(state.scenario_progress.hammer_strikes, 1, "итог не дублируется")
