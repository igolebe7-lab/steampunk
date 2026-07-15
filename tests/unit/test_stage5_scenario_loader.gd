extends TestCase

const SCENARIO_PATH := "res://data/scenarios/full_industrial.tres"


func run() -> Array[String]:
    assert_true(ResourceLoader.exists(SCENARIO_PATH), "полный индустриальный сценарий существует")
    if not ResourceLoader.exists(SCENARIO_PATH):
        return finish()
    var definition := load(SCENARIO_PATH) as ScenarioDef
    var result := ScenarioLoader.new().load_scenario(definition)
    assert_true(result.is_success(), "сценарий этапа 5 загружается без ошибок")
    if result.state == null:
        return finish()
    assert_eq(result.state.workers.size(), 6, "сценарий сохраняет шесть носильщиков")
    assert_eq(_count_sources(result.state), 4, "загружены четыре разных источника")
    assert_true(_find_building(result.state, &"pump_station") != null, "насосная существует")
    assert_true(_find_building(result.state, &"boiler") != null, "котёл существует")
    assert_true(_find_building(result.state, &"steam_hammer") != null, "паровой молот существует")
    assert_eq(result.state.production_states.size(), 2, "котёл и молот имеют production state")
    var boiler := _find_building(result.state, &"boiler")
    var hammer := _find_building(result.state, &"steam_hammer")
    var boiler_production := result.state.production_states.get(boiler.id) as ProductionState
    var hammer_production := result.state.production_states.get(hammer.id) as ProductionState
    assert_eq(boiler_production.linked_building_id, hammer.id, "котёл локально связан с молотом")
    assert_eq(hammer_production.linked_building_id, boiler.id, "молот локально связан с котлом")
    assert_eq(definition.observation_ticks, 900, "наблюдение длится 900 тиков")
    return finish()


func _count_sources(state: SimulationState) -> int:
    var count := 0
    var resources: Dictionary = {}
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        var definition := state.catalog.get_building(building.definition_id)
        if definition != null and definition.is_source():
            count += 1
            resources[definition.source_resource_id] = true
    assert_eq(resources.size(), 4, "каждый источник создаёт отдельный ресурс")
    return count


func _find_building(state: SimulationState, definition_id: StringName) -> BuildingState:
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        if building.definition_id == definition_id:
            return building
    return null
