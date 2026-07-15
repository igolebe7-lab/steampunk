class_name LogisticsGraphTestFactory
extends RefCounted

const WOOD := &"wood"


static func basic(include_transfer: bool = true) -> SimulationState:
    var catalog := DefinitionCatalog.new()
    var wood := ResourceDef.new()
    wood.id = WOOD
    wood.display_name_key = &"resource.wood.name"
    catalog.resources = [wood]
    for level in range(RoadLevelDef.LEVEL_OPEN_GROUND, RoadLevelDef.LEVEL_DIRT_ROAD + 1):
        var road := RoadLevelDef.new()
        road.level = level
        road.traversal_ticks = 4 - level
        road.upgrade_cost = level
        catalog.road_levels.append(road)

    var source_definition := BuildingDef.new()
    source_definition.id = &"wood_source"
    source_definition.display_name_key = &"building.wood_source.name"
    source_definition.inventory_capacity = 8
    source_definition.source_resource_id = WOOD
    source_definition.source_interval_ticks = 10
    source_definition.source_capacity = 8
    source_definition.role = LogisticsPortDef.ROLE_SOURCE
    source_definition.outgoing_worker_slots_by_level = [2]
    var output := LogisticsPortDef.new()
    output.direction = LogisticsPortDef.DIRECTION_OUTPUT
    output.resource_id = WOOD
    output.accepted_building_roles = [
        LogisticsPortDef.ROLE_MAIN_WAREHOUSE,
        LogisticsPortDef.ROLE_TRANSFER_DEPOT,
    ]
    source_definition.logistics_ports = [output]

    var main_definition := BuildingDef.new()
    main_definition.id = &"main_warehouse"
    main_definition.display_name_key = &"building.main_warehouse.name"
    main_definition.inventory_capacity = 100
    main_definition.role = LogisticsPortDef.ROLE_MAIN_WAREHOUSE
    main_definition.outgoing_worker_slots_by_level = [0]

    var transfer_definition := BuildingDef.new()
    transfer_definition.id = &"transfer_depot"
    transfer_definition.display_name_key = &"building.transfer_depot.name"
    transfer_definition.inventory_capacity = 40
    transfer_definition.role = LogisticsPortDef.ROLE_TRANSFER_DEPOT
    transfer_definition.outgoing_worker_slots_by_level = [2]
    catalog.buildings = [source_definition, main_definition, transfer_definition]

    var map_state := HexMapState.new(8, 5)
    var source := BuildingState.new(1, source_definition.id, HexCoord.new(0, 0), 2)
    source.inventory_capacity = source_definition.inventory_capacity
    var main := BuildingState.new(2, main_definition.id, HexCoord.new(6, 0), 2)
    main.inventory_capacity = main_definition.inventory_capacity
    var buildings: Dictionary = {1: source, 2: main}
    var occupied: Dictionary = {source.coord.key(): 1, main.coord.key(): 2}
    var next_id := 3
    if include_transfer:
        var transfer := BuildingState.new(3, transfer_definition.id, HexCoord.new(3, 0), 2)
        transfer.inventory_capacity = transfer_definition.inventory_capacity
        buildings[3] = transfer
        occupied[transfer.coord.key()] = 3
        next_id = 4

    var state := SimulationState.new(1, map_state, catalog, buildings, occupied, next_id)
    state.main_warehouse_id = 2
    state.logistics_topology_dirty = true
    return state


static func add_building(
    state: SimulationState,
    entity_id: int,
    definition_id: StringName,
    coord: HexCoord
) -> BuildingState:
    var definition := state.catalog.get_building(definition_id)
    var building := BuildingState.new(entity_id, definition_id, coord, 2)
    building.inventory_capacity = definition.inventory_capacity
    state.buildings[entity_id] = building
    state.occupied_cells[coord.key()] = entity_id
    state.next_entity_id = maxi(state.next_entity_id, entity_id + 1)
    state.logistics_topology_dirty = true
    return building
