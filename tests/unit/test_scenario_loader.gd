extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    assert_true(scenario != null, "подготовленный сценарий должен загружаться как ресурс")
    if scenario == null:
        return finish()

    var result := ScenarioLoader.new().load_scenario(scenario)
    assert_true(result.is_success(), "подготовленный сценарий должен создавать состояние")
    if result.state != null:
        assert_eq(result.state.map_state.cell_count(), 324, "сценарий должен создать карту 18×18")
        assert_eq(result.state.buildings.size(), 3, "сценарий должен создать три здания")
        assert_eq(result.state.tick, 0, "новая симуляция должна начинаться до первого тика")
        assert_eq(result.state.next_entity_id, 4, "следующий ID должен учитывать три здания")

    var invalid := ScenarioDef.new()
    invalid.width = 18
    invalid.height = 18
    invalid.seed = 1
    invalid.catalog = scenario.catalog
    var missing_building := InitialBuildingDef.new()
    missing_building.definition_id = &"missing"
    missing_building.offset_coord = Vector2i(2, 2)
    invalid.initial_buildings = [missing_building]
    var rejected := ScenarioLoader.new().load_scenario(invalid)
    assert_true(not rejected.is_success(), "неизвестное здание должно отклонять весь сценарий")
    assert_true(rejected.errors.has(&"unknown_building_definition"), "отказ должен иметь структурированный код")
    assert_eq(rejected.state, null, "ошибочная загрузка не должна возвращать частичное состояние")
    return finish()
