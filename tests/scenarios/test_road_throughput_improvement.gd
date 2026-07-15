extends TestCase

const DURATION_TICKS := 600
const REQUIRED_GAIN := 0.25


func run() -> Array[String]:
    var baseline := _state()
    var improved := _state()
    _upgrade_source_corridors(improved)
    assert_eq(baseline.seed, improved.seed, "baseline и improved используют одинаковый seed")
    assert_eq(_initial_inventories(baseline), _initial_inventories(improved), "дороги не дают скрытый бонус складу")

    SimulationRunner.new(baseline).run_ticks(DURATION_TICKS)
    SimulationRunner.new(improved).run_ticks(DURATION_TICKS)
    var baseline_units := baseline.telemetry_window.cumulative_main_deliveries.get(&"wood", 0) as int
    var improved_units := improved.telemetry_window.cumulative_main_deliveries.get(&"wood", 0) as int
    var gain := 0.0 if baseline_units == 0 else float(improved_units - baseline_units) / float(baseline_units)
    print("ROAD_ACCEPTANCE baseline=%d improved=%d gain=%.2f%%" % [baseline_units, improved_units, gain * 100.0])
    assert_true(baseline_units > 0, "baseline выполняет доставки")
    assert_true(gain >= REQUIRED_GAIN, "road corridor повышает throughput минимум на 25%")
    assert_eq(_wood_in_world(baseline), baseline.generated_totals.get(&"wood", 0), "baseline сохраняет древесину")
    assert_eq(_wood_in_world(improved), improved.generated_totals.get(&"wood", 0), "improved сохраняет древесину")
    return finish()


func _upgrade_source_corridors(state: SimulationState) -> void:
    var pathfinder := Pathfinder.new()
    var main_goals := pathfinder.interaction_cells(state, state.main_warehouse_id)
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        var definition := state.catalog.get_building(building.definition_id)
        if definition == null or not definition.is_source():
            continue
        var best_path: Array[HexCoord] = []
        var best_cost := 1 << 30
        for start: HexCoord in pathfinder.interaction_cells(state, building.id):
            var result := pathfinder.find_path(state, start, main_goals)
            if result.is_success() and result.cost < best_cost:
                best_path = result.path
                best_cost = result.cost
        for coord: HexCoord in best_path:
            state.map_state.get_cell(coord).road_level = RoadLevelDef.LEVEL_DIRT_ROAD


func _initial_inventories(state: SimulationState) -> Dictionary:
    var result: Dictionary = {}
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        result[building.id] = building.inventories.duplicate()
    return result


func _state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return ScenarioLoader.new().load_scenario(scenario).state


func _wood_in_world(state: SimulationState) -> int:
    var total := 0
    for value: Variant in state.buildings.values():
        total += (value as BuildingState).get_amount(&"wood")
    for value: Variant in state.workers.values():
        total += 1 if (value as WorkerState).cargo_resource_id == &"wood" else 0
    return total
