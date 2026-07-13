class_name StateHasher
extends RefCounted


func canonicalize(state: SimulationState) -> String:
    var cells := state.map_state.get_cells()
    cells.sort_custom(_sort_cells)
    var cell_parts: PackedStringArray = []
    for cell in cells:
        cell_parts.append(
            "%d,%d,%d,%d" % [
                cell.coord.q,
                cell.coord.r,
                int(cell.traversable),
                cell.movement_cost,
            ]
        )

    var building_ids: Array[int] = []
    for key in state.buildings:
        building_ids.append(key as int)
    building_ids.sort()

    var building_parts: PackedStringArray = []
    for entity_id in building_ids:
        var building := state.get_building(entity_id)
        building_parts.append(
            "%d,%s,%d,%d,%d" % [
                building.id,
                _encode_identifier(building.definition_id),
                building.coord.q,
                building.coord.r,
                building.priority,
            ]
        )
    return "v=2|tick=%d|seed=%d|next=%d|map=%d,%d|cells=[%s]|buildings=[%s]" % [
        state.tick,
        state.seed,
        state.next_entity_id,
        state.map_state.width,
        state.map_state.height,
        ";".join(cell_parts),
        ";".join(building_parts),
    ]


func hash_state(state: SimulationState) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(canonicalize(state).to_utf8_buffer())
    return context.finish().hex_encode()


func _encode_identifier(identifier: StringName) -> String:
    var value := String(identifier)
    return "%d:%s" % [value.length(), value]


func _sort_cells(left: HexCellState, right: HexCellState) -> bool:
    if left.coord.q == right.coord.q:
        return left.coord.r < right.coord.r
    return left.coord.q < right.coord.q
