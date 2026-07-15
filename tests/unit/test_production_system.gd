extends TestCase


func run() -> Array[String]:
    assert_true(ResourceLoader.exists("res://src/simulation/systems/production_system.gd"), "система производства существует")
    if not ResourceLoader.exists("res://src/simulation/systems/production_system.gd"):
        return finish()
    _assert_five_cycles_heat_and_shortage_cools()
    _assert_inputs_are_consumed_atomically()
    _assert_hammer_requires_full_heat()
    return finish()


func _assert_five_cycles_heat_and_shortage_cools() -> void:
    var state := Stage5TestFactory.hot_boiler_state()
    var system := ProductionSystem.new()
    for tick in range(1, 601):
        system.run(state, tick)
    var boiler := Stage5TestFactory.production(state, &"boiler")
    assert_eq(boiler.heat_level, 5, "пять полных циклов дают устойчивый прогрев")
    assert_eq(boiler.completed_cycles, 5, "каждый цикл учтён один раз")

    for tick in range(601, 801):
        system.run(state, tick)
    assert_eq(boiler.heat_level, 4, "200 тиков простоя снимают одну ступень жара")


func _assert_inputs_are_consumed_atomically() -> void:
    var state := Stage5TestFactory.hot_boiler_state(0)
    var boiler := Stage5TestFactory.building(state, &"boiler")
    boiler.inventories[&"coal"] = 1
    boiler.inventories[&"water"] = 1

    ProductionSystem.new().run(state, 1)

    var production := Stage5TestFactory.production(state, &"boiler")
    assert_eq(boiler.get_amount(&"coal"), 1, "неполный набор не расходует уголь")
    assert_eq(boiler.get_amount(&"water"), 1, "неполный набор не расходует воду")
    assert_eq(production.progress_ticks, 0, "неполный набор не запускает прогресс")
    assert_eq(production.blocked_reason, &"no_water", "причина дефицита детерминирована")


func _assert_hammer_requires_full_heat() -> void:
    var state := Stage5TestFactory.production_state()
    var hammer := Stage5TestFactory.building(state, &"steam_hammer")
    var hammer_production := Stage5TestFactory.production(state, &"steam_hammer")
    var boiler_production := Stage5TestFactory.production(state, &"boiler")
    hammer_production.recipe_id = &"first_hammer_strike"
    hammer_production.status = ProductionState.WAITING_INPUTS
    hammer.inventories[&"iron"] = 2
    boiler_production.heat_level = 4

    var system := ProductionSystem.new()
    system.run(state, 1)
    assert_eq(hammer_production.status, ProductionState.BLOCKED, "молот ждёт полного жара")
    assert_eq(hammer.get_amount(&"iron"), 2, "ожидание жара не расходует железо")

    boiler_production.heat_level = 5
    for tick in range(2, 62):
        system.run(state, tick)
    assert_eq(hammer_production.status, ProductionState.COMPLETED, "первый удар завершён")
    assert_eq(_event_count(state, &"hammer_struck"), 1, "удар порождает единственное событие")


func _event_count(state: SimulationState, code: StringName) -> int:
    var result := 0
    for event: SimulationEvent in state.events:
        if event.code == code:
            result += 1
    return result
