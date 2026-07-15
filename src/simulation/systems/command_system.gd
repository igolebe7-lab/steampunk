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
    if command.type == SimulationCommand.PLACE_DEPOT:
        return _apply_place_depot(state, command as DepotCommand)
    if command.type == SimulationCommand.DEMOLISH_DEPOT:
        return _apply_demolish_depot(state, command as DepotCommand)
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
    state.consumed_totals[WOOD] = (state.consumed_totals.get(WOOD, 0) as int) + total_cost
    for upgrade in upgrades:
        var cell := upgrade[&"cell"] as HexCellState
        cell.road_level = upgrade[&"level"] as int
    return CommandResult.success(
        command.id,
        {&"cost": total_cost, &"cell_count": upgrades.size()}
    )


func _apply_place_depot(state: SimulationState, command: DepotCommand) -> CommandResult:
    if command == null or command.coord == null:
        return CommandResult.rejected(&"invalid_command")
    var payer_result := _validate_payer(state, command.id)
    if payer_result != null:
        return payer_result
    for value: Variant in state.buildings.values():
        if (value as BuildingState).definition_id == &"transfer_depot":
            return CommandResult.rejected(&"transfer_depot_exists", command.id)
    var coord := command.coord
    if not state.map_state.contains(coord):
        return _cell_rejection(&"cell_missing", command.id, coord, 0)
    var cell := state.map_state.get_cell(coord)
    if not cell.traversable:
        return _cell_rejection(&"cell_not_traversable", command.id, coord, 0)
    if state.occupied_cells.has(coord.key()):
        return _cell_rejection(&"cell_occupied", command.id, coord, 0)
    var has_road := false
    for neighbor: HexCoord in coord.neighbors():
        if state.map_state.contains(neighbor) and state.map_state.get_cell(neighbor).road_level >= RoadLevelDef.LEVEL_PATH:
            has_road = true
            break
    if not has_road:
        return CommandResult.rejected(&"depot_not_adjacent_to_road", command.id)
    var payer := state.get_building(state.main_warehouse_id)
    var available := payer.get_amount(WOOD) - payer.get_outgoing_reserved(WOOD)
    if available < 10:
        return CommandResult.rejected(&"insufficient_wood", command.id, {&"required": 10, &"available": available})
    var definition := state.catalog.get_building(&"transfer_depot")
    if definition == null:
        return CommandResult.rejected(&"unknown_building_definition", command.id)
    if not payer.remove_amount(WOOD, 10):
        return CommandResult.rejected(&"insufficient_wood", command.id)
    var building_id := state.next_entity_id
    var depot := BuildingState.new(building_id, definition.id, coord, 2)
    depot.inventory_capacity = definition.inventory_capacity
    depot.allows_direct_delivery_to_main = definition.allows_direct_delivery_to_main
    state.buildings[building_id] = depot
    state.occupied_cells[coord.key()] = building_id
    state.next_entity_id += 1
    state.consumed_totals[WOOD] = (state.consumed_totals.get(WOOD, 0) as int) + 10
    return CommandResult.success(command.id, {&"building_id": building_id, &"cost": 10})


func _apply_demolish_depot(state: SimulationState, command: DepotCommand) -> CommandResult:
    if command == null:
        return CommandResult.rejected(&"invalid_command")
    var depot := state.get_building(command.building_id)
    if depot == null or depot.definition_id != &"transfer_depot":
        return CommandResult.rejected(&"unknown_transfer_depot", command.id)
    if depot.inventory_total() > 0:
        return CommandResult.rejected(&"depot_not_empty", command.id)
    if _has_positive_reservations(depot.incoming_reserved) or _has_positive_reservations(depot.outgoing_reserved):
        return CommandResult.rejected(&"depot_has_reservations", command.id)
    for value: Variant in state.jobs.values():
        var job := value as DeliveryJob
        if job.source_id == depot.id or job.destination_id == depot.id:
            return CommandResult.rejected(&"depot_has_active_jobs", command.id)
    var payer_result := _validate_payer(state, command.id)
    if payer_result != null:
        return payer_result
    var payer := state.get_building(state.main_warehouse_id)
    if not payer.add_amount(WOOD, 5):
        return CommandResult.rejected(&"main_warehouse_full", command.id)
    state.buildings.erase(depot.id)
    state.occupied_cells.erase(depot.coord.key())
    state.consumed_totals[WOOD] = maxi((state.consumed_totals.get(WOOD, 0) as int) - 5, 0)
    return CommandResult.success(command.id, {&"refund": 5})


func _has_positive_reservations(reservations: Dictionary) -> bool:
    for amount: Variant in reservations.values():
        if (amount as int) > 0:
            return true
    return false


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
