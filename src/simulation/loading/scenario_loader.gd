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
    if not errors.is_empty():
        return ScenarioLoadResult.new(null, errors)

    var map_state := HexMapState.new(definition.width, definition.height)
    var buildings: Dictionary = {}
    var occupied_cells: Dictionary = {}
    var next_entity_id := 1

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
        buildings[next_entity_id] = building
        for coord in footprint_cells:
            occupied_cells[coord.key()] = next_entity_id
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
    return ScenarioLoadResult.new(state, errors)


func _offset_to_axial(offset_coord: Vector2i) -> HexCoord:
    var axial_r := offset_coord.y - (offset_coord.x - (offset_coord.x & 1)) / 2
    return HexCoord.new(offset_coord.x, axial_r)
