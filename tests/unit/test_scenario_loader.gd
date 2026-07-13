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

    var duplicate_footprint := BuildingDef.new()
    duplicate_footprint.id = &"duplicate_footprint"
    duplicate_footprint.display_name_key = &"building.duplicate.name"
    duplicate_footprint.footprint = [Vector2i.ZERO, Vector2i.ZERO]
    var invalid_catalog := DefinitionCatalog.new()
    invalid_catalog.buildings = [duplicate_footprint]
    var invalid_footprint_scenario := ScenarioDef.new()
    invalid_footprint_scenario.catalog = invalid_catalog
    var invalid_initial := InitialBuildingDef.new()
    invalid_initial.definition_id = duplicate_footprint.id
    invalid_footprint_scenario.initial_buildings = [invalid_initial]
    var invalid_footprint_result := ScenarioLoader.new().load_scenario(invalid_footprint_scenario)
    assert_true(
        not invalid_footprint_result.is_success(),
        "сценарий с повтором клетки footprint должен отклоняться атомарно"
    )
    assert_eq(
        invalid_footprint_result.state,
        null,
        "сценарий с нарушением footprint не должен возвращать состояние"
    )
    return finish()
