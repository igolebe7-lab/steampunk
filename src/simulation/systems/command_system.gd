class_name CommandSystem
extends RefCounted

const WOOD := &"wood"


func apply(state: SimulationState, command: SimulationCommand) -> CommandResult:
    if state == null or command == null:
        return CommandResult.rejected(&"invalid_command")
    if command.type == SimulationCommand.SET_BUILDING_PRIORITY:
        return _apply_building_priority(state, command as BuildingPriorityCommand)
    if command.type == SimulationCommand.BUILD_ROAD:
        return _apply_build_road(state, command as BuildRoadCommand)
    return CommandResult.rejected(&"unsupported_command", command.id)


func _apply_building_priority(
    state: SimulationState,
    command: BuildingPriorityCommand
) -> CommandResult:
    if command == null:
        return CommandResult.rejected(&"invalid_command")

    var building := state.get_building(command.building_id)
    if building == null:
        return CommandResult.rejected(&"unknown_building", command.id)
    if command.priority < 0 or command.priority > 4:
        return CommandResult.rejected(&"invalid_priority", command.id)

    building.priority = command.priority
    return CommandResult.success(command.id)


func _apply_build_road(state: SimulationState, command: BuildRoadCommand) -> CommandResult:
    if command == null:
        return CommandResult.rejected(&"invalid_command")
    var payer_result := _validate_payer(state, command.id)
    if payer_result != null:
        return payer_result

    var coords := command.coords
    if coords.is_empty():
        return CommandResult.rejected(&"empty_road_batch", command.id)

    var upgrades: Array[Dictionary] = []
    var seen: Dictionary = {}
    var total_cost := 0
    for index in coords.size():
        var coord := coords[index]
        if coord == null or not state.map_state.contains(coord):
            return _cell_rejection(&"cell_missing", command.id, coord, index)
        var key := coord.key()
        if seen.has(key):
            return _cell_rejection(&"duplicate_cell", command.id, coord, index)
        seen[key] = true

        var cell := state.map_state.get_cell(coord)
        if not cell.traversable:
            return _cell_rejection(&"cell_not_traversable", command.id, coord, index)
        if state.occupied_cells.has(key):
            return _cell_rejection(&"cell_occupied", command.id, coord, index)
        if cell.road_level < RoadLevelDef.LEVEL_OPEN_GROUND:
            return _cell_rejection(&"invalid_road_level", command.id, coord, index)
        if cell.road_level >= RoadLevelDef.LEVEL_DIRT_ROAD:
            return _cell_rejection(&"road_level_max", command.id, coord, index)

        var next_level := cell.road_level + 1
        var upgrade_cost := _road_upgrade_cost(state, next_level)
        if upgrade_cost < 0:
            return CommandResult.rejected(
                &"missing_road_level",
                command.id,
                {&"level": next_level}
            )
        total_cost += upgrade_cost
        upgrades.append({&"cell": cell, &"level": next_level})

    var payer := state.get_building(state.main_warehouse_id)
    var available := payer.get_amount(WOOD) - payer.get_outgoing_reserved(WOOD)
    if available < total_cost:
        return CommandResult.rejected(
            &"insufficient_wood",
            command.id,
            {&"required": total_cost, &"available": available}
        )

    if total_cost > 0 and not payer.remove_amount(WOOD, total_cost):
        return CommandResult.rejected(&"insufficient_wood", command.id)
    for upgrade in upgrades:
        var cell := upgrade[&"cell"] as HexCellState
        cell.road_level = upgrade[&"level"] as int
    return CommandResult.success(
        command.id,
        {&"cost": total_cost, &"cell_count": upgrades.size()}
    )


func _validate_payer(state: SimulationState, command_id: StringName) -> CommandResult:
    if state.main_warehouse_id <= 0 or state.get_building(state.main_warehouse_id) == null:
        return CommandResult.rejected(&"unknown_main_warehouse", command_id)
    return null


func _road_upgrade_cost(state: SimulationState, target_level: int) -> int:
    var definition := state.catalog.get_road_level(target_level)
    return -1 if definition == null else definition.upgrade_cost


func _cell_rejection(
    code: StringName,
    command_id: StringName,
    coord: HexCoord,
    index: int
) -> CommandResult:
    return CommandResult.rejected(
        code,
        command_id,
        {
            &"coord": &"" if coord == null else coord.key(),
            &"index": index,
        }
    )
