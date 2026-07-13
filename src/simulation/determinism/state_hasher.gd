class_name StateHasher
extends RefCounted


func canonicalize(state: SimulationState) -> String:
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
                building.definition_id,
                building.coord.q,
                building.coord.r,
                building.priority,
            ]
        )
    return "tick=%d|seed=%d|next=%d|buildings=[%s]" % [
        state.tick,
        state.seed,
        state.next_entity_id,
        ";".join(building_parts),
    ]


func hash_state(state: SimulationState) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(canonicalize(state).to_utf8_buffer())
    return context.finish().hex_encode()
