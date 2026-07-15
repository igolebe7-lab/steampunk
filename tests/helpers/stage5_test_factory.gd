class_name Stage5TestFactory
extends RefCounted

const IRON := &"iron"
const WATER := &"water"


static func production_state() -> SimulationState:
    var scenario := load("res://data/scenarios/full_industrial.tres") as ScenarioDef
    var result := ScenarioLoader.new().load_scenario(scenario)
    return result.state


static func scenario_state() -> SimulationState:
    return production_state()


static func building(state: SimulationState, definition_id: StringName) -> BuildingState:
    var ids: Array[int] = []
    for key: Variant in state.buildings.keys():
        ids.append(key as int)
    ids.sort()
    for id: int in ids:
        var candidate := state.get_building(id)
        if candidate.definition_id == definition_id:
            return candidate
    return null


static func production(state: SimulationState, definition_id: StringName) -> ProductionState:
    var target := building(state, definition_id)
    return null if target == null else state.production_states.get(target.id) as ProductionState


static func hot_boiler_state(cycles: int = 5) -> SimulationState:
    var state := production_state()
    var boiler := building(state, &"boiler")
    var production_state := production(state, &"boiler")
    production_state.status = ProductionState.WAITING_INPUTS
    boiler.inventories[&"coal"] = cycles
    boiler.inventories[&"water"] = cycles * 2
    return state


static func isolate_link(
    state: SimulationState,
    source_id: int,
    destination_id: int,
    resource_id: StringName,
    quota: int
) -> LogisticsLinkState:
    state.logistics_links.clear()
    var link := LogisticsLinkState.new(1, source_id, destination_id, resource_id, false, quota, 2)
    state.logistics_links[link.id] = link
    state.next_link_id = 2
    var worker_ids: Array[int] = []
    for key: Variant in state.workers.keys():
        worker_ids.append(key as int)
    worker_ids.sort()
    for index in mini(quota, worker_ids.size()):
        (state.get_worker(worker_ids[index]) as WorkerState).link_id = link.id
    return link


static func pipe_state(iron: int = 10) -> SimulationState:
    var catalog := DefinitionCatalog.new()
    catalog.resources = [_resource(IRON), _resource(WATER)]

    var main_def := _building(&"main_warehouse", LogisticsPortDef.ROLE_MAIN_WAREHOUSE, 100)
    var pump_def := _building(&"pump_station", LogisticsPortDef.ROLE_SOURCE, 0)
    pump_def.utility_ports = [_utility_port(UtilityPortDef.DIRECTION_OUTPUT, WATER)]
    var boiler_def := _building(&"boiler", LogisticsPortDef.ROLE_PRODUCTION, 9)
    boiler_def.utility_ports = [_utility_port(UtilityPortDef.DIRECTION_INPUT, WATER)]
    catalog.buildings = [main_def, pump_def, boiler_def]

    var map_state := HexMapState.new(8, 5)
    var main := _state_building(1, main_def, HexCoord.new(0, 3))
    main.inventories[IRON] = iron
    var pump := _state_building(2, pump_def, HexCoord.new(1, 0))
    var boiler := _state_building(3, boiler_def, HexCoord.new(5, 0))
    var buildings: Dictionary = {1: main, 2: pump, 3: boiler}
    var occupied: Dictionary = {
        main.coord.key(): main.id,
        pump.coord.key(): pump.id,
        boiler.coord.key(): boiler.id,
    }
    var state := SimulationState.new(5, map_state, catalog, buildings, occupied, 4)
    state.main_warehouse_id = main.id
    return state


static func pipe_path() -> Array[HexCoord]:
    return [HexCoord.new(2, 0), HexCoord.new(3, 0), HexCoord.new(4, 0)]


static func connected_pipe_state() -> SimulationState:
    var state := pipe_state(10)
    var result := CommandSystem.new().apply(state, PipeCommand.build(1, 1, pipe_path()))
    assert(result.accepted, "тестовая труба должна строиться")
    return state


static func _resource(id: StringName) -> ResourceDef:
    var definition := ResourceDef.new()
    definition.id = id
    definition.display_name_key = StringName("resource.%s.name" % id)
    return definition


static func _building(id: StringName, role: StringName, capacity: int) -> BuildingDef:
    var definition := BuildingDef.new()
    definition.id = id
    definition.display_name_key = StringName("building.%s.name" % id)
    definition.role = role
    definition.inventory_capacity = capacity
    definition.outgoing_worker_slots_by_level = [0]
    return definition


static func _utility_port(direction: StringName, commodity_id: StringName) -> UtilityPortDef:
    var port := UtilityPortDef.new()
    port.direction = direction
    port.commodity_id = commodity_id
    return port


static func _state_building(id: int, definition: BuildingDef, coord: HexCoord) -> BuildingState:
    var building := BuildingState.new(id, definition.id, coord, 2)
    building.inventory_capacity = definition.inventory_capacity
    return building
