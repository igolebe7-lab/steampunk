class_name Stage5TestFactory
extends RefCounted

const IRON := &"iron"
const WATER := &"water"


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
