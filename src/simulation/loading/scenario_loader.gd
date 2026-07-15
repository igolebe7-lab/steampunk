class_name ScenarioLoader
extends RefCounted


func load_scenario(definition: ScenarioDef) -> ScenarioLoadResult:
    var errors: Array[StringName] = []
    if definition == null:
        errors.append(&"missing_scenario")
        return ScenarioLoadResult.new(null, errors)
    if definition.catalog == null:
        errors.append(&"missing_catalog")
    else:
        errors.append_array(definition.catalog.validate())
    if definition.width <= 0 or definition.height <= 0:
        errors.append(&"invalid_map_size")
    if definition.seed <= 0:
        errors.append(&"invalid_seed")
    if (
        definition.worker_ticks_per_hex < 1
        or definition.worker_ticks_per_hex > 100
        or definition.load_ticks < 1
        or definition.load_ticks > 100
        or definition.unload_ticks < 1
        or definition.unload_ticks > 100
        or definition.repath_after_ticks < 1
        or definition.repath_after_ticks > 100
    ):
        errors.append(&"invalid_simulation_timing")
    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)

    var map_state := HexMapState.new(definition.width, definition.height)
    var buildings: Dictionary = {}
    var occupied_cells: Dictionary = {}
    var scenario_keys: Dictionary = {}
    var next_entity_id := 1
    var main_warehouse_id := 0

    for initial in definition.initial_buildings:
        if initial == null or initial.definition_id.is_empty():
            errors.append(&"invalid_initial_building")
            continue

        var building_def := definition.catalog.get_building(initial.definition_id)
        if building_def == null:
            errors.append(&"unknown_building_definition")
            continue
        if initial.priority < 0 or initial.priority > 4:
            errors.append(&"invalid_building_priority")
            continue

        var footprint_cells: Array[HexCoord] = []
        var footprint_is_valid := true
        for offset in building_def.footprint:
            var offset_coord := initial.offset_coord + offset
            var coord := _offset_to_axial(offset_coord)
            if not map_state.contains(coord):
                errors.append(&"building_out_of_bounds")
                footprint_is_valid = false
                break
            if occupied_cells.has(coord.key()):
                errors.append(&"building_overlap")
                footprint_is_valid = false
                break
            footprint_cells.append(coord)

        if not footprint_is_valid:
            continue

        var anchor := _offset_to_axial(initial.offset_coord)
        var building := BuildingState.new(
            next_entity_id,
            initial.definition_id,
            anchor,
            initial.priority
        )
        building.inventory_capacity = building_def.inventory_capacity
        building.allows_direct_delivery_to_main = building_def.allows_direct_delivery_to_main
        buildings[next_entity_id] = building
        if building_def.role == LogisticsPortDef.ROLE_MAIN_WAREHOUSE:
            if main_warehouse_id != 0:
                errors.append(&"multiple_main_warehouses")
            else:
                main_warehouse_id = next_entity_id
        if not initial.scenario_key.is_empty():
            if scenario_keys.has(initial.scenario_key):
                errors.append(&"duplicate_scenario_key")
            else:
                scenario_keys[initial.scenario_key] = next_entity_id
        for coord in footprint_cells:
            occupied_cells[coord.key()] = next_entity_id
        next_entity_id += 1

    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)

    var workers: Dictionary = {}
    var worker_occupancy: Dictionary = {}
    for initial_worker in definition.initial_workers:
        if initial_worker == null:
            errors.append(&"invalid_initial_worker")
            continue
        var worker_coord := _offset_to_axial(initial_worker.offset_coord)
        if not map_state.contains(worker_coord):
            errors.append(&"worker_out_of_bounds")
            continue
        if occupied_cells.has(worker_coord.key()):
            errors.append(&"worker_on_building")
            continue
        if worker_occupancy.has(worker_coord.key()):
            errors.append(&"worker_overlap")
            continue
        workers[next_entity_id] = WorkerState.new(next_entity_id, worker_coord)
        worker_occupancy[worker_coord.key()] = next_entity_id
        next_entity_id += 1

    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)

    var state := SimulationState.new(
        definition.seed,
        map_state,
        definition.catalog,
        buildings,
        occupied_cells,
        next_entity_id
    )
    state.workers = workers
    state.main_warehouse_id = main_warehouse_id
    state.worker_occupancy = worker_occupancy

    var logistics_links: Dictionary = {}
    var link_system := LogisticsLinkSystem.new()
    var flow_id := 1
    for initial_flow in definition.delivery_flows:
        if initial_flow == null or initial_flow.source_key.is_empty() or initial_flow.destination_key.is_empty():
            errors.append(&"invalid_delivery_flow")
            continue
        if not scenario_keys.has(initial_flow.source_key) or not scenario_keys.has(initial_flow.destination_key):
            errors.append(&"unknown_flow_building")
            continue
        if definition.catalog.get_resource(initial_flow.resource_id) == null:
            errors.append(&"unknown_flow_resource")
            continue
        if initial_flow.priority < 0 or initial_flow.priority > 4:
            errors.append(&"invalid_flow_priority")
            continue
        var source_id := scenario_keys[initial_flow.source_key] as int
        var destination_id := scenario_keys[initial_flow.destination_key] as int
        if source_id == destination_id:
            errors.append(&"invalid_flow_endpoint")
            continue
        if not link_system.is_compatible(
            state,
            source_id,
            destination_id,
            initial_flow.resource_id
        ):
            errors.append(&"invalid_flow_source")
            continue
        logistics_links[flow_id] = LogisticsLinkState.new(
            flow_id,
            source_id,
            destination_id,
            initial_flow.resource_id,
            true,
            1,
            initial_flow.priority
        )
        flow_id += 1

    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)

    state.delivery_flows = []
    state.logistics_links = logistics_links
    state.next_link_id = flow_id
    state.logistics_topology_dirty = false
    state.worker_ticks_per_hex = definition.worker_ticks_per_hex
    state.load_ticks = definition.load_ticks
    state.unload_ticks = definition.unload_ticks
    state.repath_after_ticks = definition.repath_after_ticks
    errors.append_array(InvariantChecker.new().check(state))
    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)
    return ScenarioLoadResult.new(state, errors)


func _offset_to_axial(offset_coord: Vector2i) -> HexCoord:
    var axial_r := offset_coord.y - (offset_coord.x - (offset_coord.x & 1)) / 2
    return HexCoord.new(offset_coord.x, axial_r)
