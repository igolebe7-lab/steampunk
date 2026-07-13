class_name InvariantChecker
extends RefCounted


func check(state: SimulationState) -> Array[StringName]:
    var errors: Array[StringName] = []
    if state == null:
        return [&"missing_state"]
    if state.tick < 0:
        errors.append(&"invalid_tick")
    if state.map_state == null:
        errors.append(&"missing_map")
    if state.catalog == null:
        errors.append(&"missing_catalog")
    if state.map_state == null or state.catalog == null:
        return errors

    var expected_occupancy: Dictionary = {}
    var maximum_id := 0
    for key in state.buildings:
        var entity_id := key as int
        var building := state.buildings[key] as BuildingState
        if building == null or entity_id <= 0 or building.id != entity_id:
            errors.append(&"invalid_building_id")
            continue
        maximum_id = maxi(maximum_id, entity_id)
        if building.priority < 0 or building.priority > 4:
            errors.append(&"invalid_building_priority")
        if not state.map_state.contains(building.coord):
            errors.append(&"building_out_of_bounds")

        var definition := state.catalog.get_building(building.definition_id)
        if definition == null:
            errors.append(&"unknown_building_definition")
            continue
        for coord in _footprint_coords(building.coord, definition.footprint):
            if not state.map_state.contains(coord):
                errors.append(&"building_out_of_bounds")
                continue
            if expected_occupancy.has(coord.key()):
                errors.append(&"building_overlap")
            else:
                expected_occupancy[coord.key()] = entity_id

    if state.next_entity_id <= maximum_id:
        errors.append(&"invalid_next_entity_id")
    if expected_occupancy.size() != state.occupied_cells.size():
        errors.append(&"invalid_occupancy")
    else:
        for cell_key in expected_occupancy:
            if state.occupied_cells.get(cell_key) != expected_occupancy[cell_key]:
                errors.append(&"invalid_occupancy")
                break
    return errors


func _footprint_coords(anchor: HexCoord, offsets: Array[Vector2i]) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    if anchor == null:
        return result
    var anchor_row := anchor.r + (anchor.q - (anchor.q & 1)) / 2
    for offset in offsets:
        var column := anchor.q + offset.x
        var row := anchor_row + offset.y
        var axial_r := row - (column - (column & 1)) / 2
        result.append(HexCoord.new(column, axial_r))
    return result
