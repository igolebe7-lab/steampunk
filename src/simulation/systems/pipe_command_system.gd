class_name PipeCommandSystem
extends RefCounted

const IRON := &"iron"
const WATER := &"water"


func apply(state: SimulationState, command: PipeCommand) -> CommandResult:
    if state == null or command == null:
        return CommandResult.rejected(&"invalid_command")
    if command.operation == PipeCommand.BUILD:
        return _build(state, command)
    if command.operation == PipeCommand.REMOVE:
        return _remove(state, command)
    return CommandResult.rejected(&"unsupported_command", command.id)


func _build(state: SimulationState, command: PipeCommand) -> CommandResult:
    var validation := _validate_common(state, command)
    if validation != null:
        return validation
    var coords := command.coords
    for index in coords.size():
        var coord := coords[index]
        if state.occupied_cells.has(coord.key()):
            return _cell_rejection(&"pipe_cell_occupied", command.id, coord, index)
        if state.utility_network.has_segment(coord):
            return _cell_rejection(&"pipe_segment_exists", command.id, coord, index)
    if not _has_adjacent_port(state, coords.front(), UtilityPortDef.DIRECTION_OUTPUT, WATER):
        return CommandResult.rejected(&"invalid_pipe_origin", command.id)
    if not _has_adjacent_port(state, coords.back(), UtilityPortDef.DIRECTION_INPUT, WATER):
        return CommandResult.rejected(&"invalid_pipe_destination", command.id)

    var payer := state.get_building(state.main_warehouse_id)
    if payer == null:
        return CommandResult.rejected(&"unknown_main_warehouse", command.id)
    var cost := ceili(float(coords.size()) / 2.0)
    var available := payer.get_amount(IRON) - payer.get_outgoing_reserved(IRON)
    if available < cost:
        return CommandResult.rejected(
            &"insufficient_iron",
            command.id,
            {&"required": cost, &"available": available}
        )

    var paid := payer.remove_amount(IRON, cost)
    assert(paid, "стоимость трубы проверена до мутации")
    for coord: HexCoord in coords:
        var added := state.utility_network.add_segment(coord, WATER)
        assert(added, "сегменты проверены до мутации")
    state.consumed_totals[IRON] = (state.consumed_totals.get(IRON, 0) as int) + cost
    state.utility_network.topology_revision += 1
    var event := SimulationEvent.new(&"pipe_built", command.target_tick)
    event.metric_value = coords.size()
    state.events.append(event)
    return CommandResult.success(command.id, {&"cost": cost, &"segment_count": coords.size()})


func _remove(state: SimulationState, command: PipeCommand) -> CommandResult:
    var validation := _validate_common(state, command)
    if validation != null:
        return validation
    var coords := command.coords
    for index in coords.size():
        var coord := coords[index]
        var segment := state.utility_network.get_segment(coord)
        if segment == null:
            return _cell_rejection(&"pipe_segment_missing", command.id, coord, index)
        if segment.commodity_id != WATER:
            return _cell_rejection(&"incompatible_utility_type", command.id, coord, index)
    for coord: HexCoord in coords:
        var removed := state.utility_network.remove_segment(coord)
        assert(removed, "сегменты проверены до удаления")
    state.utility_network.topology_revision += 1
    var event := SimulationEvent.new(&"pipe_removed", command.target_tick)
    event.metric_value = coords.size()
    state.events.append(event)
    return CommandResult.success(command.id, {&"segment_count": coords.size()})


func _validate_common(state: SimulationState, command: PipeCommand) -> CommandResult:
    var coords := command.coords
    if coords.is_empty():
        return CommandResult.rejected(&"empty_pipe_path", command.id)
    var seen: Dictionary = {}
    for index in coords.size():
        var coord := coords[index]
        if coord == null or not state.map_state.contains(coord):
            return _cell_rejection(&"cell_missing", command.id, coord, index)
        if seen.has(coord.key()):
            return _cell_rejection(&"duplicate_cell", command.id, coord, index)
        seen[coord.key()] = true
        if not state.map_state.get_cell(coord).traversable:
            return _cell_rejection(&"cell_not_traversable", command.id, coord, index)
    for index in range(1, coords.size()):
        if coords[index - 1].distance_to(coords[index]) != 1:
            return _cell_rejection(&"invalid_pipe_path", command.id, coords[index], index)
    return null


func _has_adjacent_port(
    state: SimulationState,
    coord: HexCoord,
    direction: StringName,
    commodity_id: StringName
) -> bool:
    for neighbor: HexCoord in coord.neighbors():
        var building_id := state.occupied_cells.get(neighbor.key(), 0) as int
        if building_id == 0:
            continue
        var building := state.get_building(building_id)
        var definition := state.catalog.get_building(building.definition_id)
        if definition == null:
            continue
        for port: UtilityPortDef in definition.utility_ports:
            if port.direction == direction and port.commodity_id == commodity_id:
                return true
    return false


func _cell_rejection(
    code: StringName,
    command_id: StringName,
    coord: HexCoord,
    index: int
) -> CommandResult:
    return CommandResult.rejected(
        code,
        command_id,
        {&"coord": &"" if coord == null else coord.key(), &"index": index}
    )
