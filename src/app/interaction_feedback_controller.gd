class_name InteractionFeedbackController
extends RefCounted

const WATER := &"water"
const WOOD := &"wood"


func evaluate(
    state: SimulationState,
    tools: ToolController,
    hover_kind: StringName,
    hover_id: int,
    hover_coord: HexCoord,
    selected_kind: StringName = &"",
    selected_id: int = 0,
    selected_coord: HexCoord = null
) -> InteractionFeedbackState:
    var result := InteractionFeedbackState.new()
    if state == null or tools == null:
        return result
    result.mode = tools.mode
    result.hint_key = StringName("ui.hint.%s" % tools.mode)
    result.can_cancel = tools.mode != ToolController.INSPECT
    result.set_hover(hover_kind, hover_id, hover_coord)
    result.set_selection(selected_kind, selected_id, selected_coord)
    match tools.mode:
        ToolController.ROAD:
            _evaluate_road(state, hover_coord, result)
        ToolController.DEPOT:
            _evaluate_depot(state, hover_coord, result)
        ToolController.LINK_ORIGIN:
            _evaluate_link_origins(state, hover_id, result)
        ToolController.LINK_DESTINATION:
            _evaluate_link_destinations(state, tools.link_origin_id, hover_id, result)
        ToolController.PIPE_BUILD:
            _evaluate_pipe_build(state, tools.pipe_coords, hover_coord, result)
        ToolController.PIPE_REMOVE:
            _evaluate_pipe_remove(state, tools.pipe_coords, hover_coord, result)
    return result


func _evaluate_road(
    state: SimulationState,
    coord: HexCoord,
    result: InteractionFeedbackState
) -> void:
    var reason := _road_reason(state, coord)
    _set_target(result, coord, reason)
    if reason.is_empty() and coord != null:
        var preview: Array[HexCoord] = [coord]
        result.set_preview_coords(preview)
        result.cost = state.catalog.get_road_level(
            state.map_state.get_cell(coord).road_level + 1
        ).upgrade_cost


func _evaluate_depot(
    state: SimulationState,
    coord: HexCoord,
    result: InteractionFeedbackState
) -> void:
    var reason := _depot_reason(state, coord)
    _set_target(result, coord, reason)
    result.cost = 10
    if reason.is_empty() and coord != null:
        var preview: Array[HexCoord] = [coord]
        result.set_preview_coords(preview)


func _evaluate_link_origins(
    state: SimulationState,
    hover_id: int,
    result: InteractionFeedbackState
) -> void:
    var system := LogisticsLinkSystem.new()
    for source_id: int in _sorted_building_ids(state):
        for destination_id: int in _sorted_building_ids(state):
            if system.is_compatible(state, source_id, destination_id, WOOD):
                result.highlight_entity_ids.append(source_id)
                break
    _set_entity_target(result, hover_id, result.highlight_entity_ids.has(hover_id))


func _evaluate_link_destinations(
    state: SimulationState,
    source_id: int,
    hover_id: int,
    result: InteractionFeedbackState
) -> void:
    var system := LogisticsLinkSystem.new()
    for destination_id: int in _sorted_building_ids(state):
        if (
            system.is_compatible(state, source_id, destination_id, WOOD)
            and not system.would_create_cycle(state, source_id, destination_id)
        ):
            result.highlight_entity_ids.append(destination_id)
    _set_entity_target(result, hover_id, result.highlight_entity_ids.has(hover_id))


func _evaluate_pipe_build(
    state: SimulationState,
    path: Array[HexCoord],
    hover_coord: HexCoord,
    result: InteractionFeedbackState
) -> void:
    var valid := _pipe_starts(state) if path.is_empty() else _pipe_extensions(state, path)
    result.set_highlight_coords(valid)
    result.set_preview_coords(path)
    result.cost = ceili(float(path.size()) / 2.0)
    result.can_confirm = _pipe_path_complete(state, path)
    if hover_coord == null:
        return
    var is_valid := _has_coord(valid, hover_coord)
    result.target_state = InteractionFeedbackState.VALID if is_valid else InteractionFeedbackState.INVALID
    if is_valid:
        var preview := _copy_coords(path)
        preview.append(HexCoord.new(hover_coord.q, hover_coord.r))
        result.set_preview_coords(preview)
        result.cost = ceili(float(preview.size()) / 2.0)
    else:
        result.reason_code = &"invalid_pipe_path"


func _evaluate_pipe_remove(
    state: SimulationState,
    path: Array[HexCoord],
    hover_coord: HexCoord,
    result: InteractionFeedbackState
) -> void:
    var valid: Array[HexCoord] = []
    if path.is_empty():
        for value: Variant in state.utility_network.segments.values():
            valid.append((value as UtilitySegmentState).coord)
    else:
        for neighbor: HexCoord in path[-1].neighbors():
            if state.utility_network.has_segment(neighbor) and not _has_coord(path, neighbor):
                valid.append(neighbor)
    result.set_highlight_coords(valid)
    result.set_preview_coords(path)
    result.can_confirm = not path.is_empty()
    if hover_coord != null:
        var is_valid := _has_coord(valid, hover_coord)
        result.target_state = InteractionFeedbackState.VALID if is_valid else InteractionFeedbackState.INVALID
        if not is_valid:
            result.reason_code = &"pipe_segment_missing"


func _road_reason(state: SimulationState, coord: HexCoord) -> StringName:
    if coord == null or not state.map_state.contains(coord):
        return &"cell_missing"
    var cell := state.map_state.get_cell(coord)
    if not cell.traversable:
        return &"cell_not_traversable"
    if state.occupied_cells.has(coord.key()):
        return &"cell_occupied"
    if cell.road_level >= RoadLevelDef.LEVEL_DIRT_ROAD:
        return &"road_level_max"
    var definition := state.catalog.get_road_level(cell.road_level + 1)
    if definition == null:
        return &"missing_road_level"
    var main := state.get_building(state.main_warehouse_id)
    if main == null:
        return &"unknown_main_warehouse"
    if main.get_amount(WOOD) - main.get_outgoing_reserved(WOOD) < definition.upgrade_cost:
        return &"insufficient_wood"
    return &""


func _depot_reason(state: SimulationState, coord: HexCoord) -> StringName:
    if coord == null or not state.map_state.contains(coord):
        return &"cell_missing"
    var cell := state.map_state.get_cell(coord)
    if not cell.traversable:
        return &"cell_not_traversable"
    if state.occupied_cells.has(coord.key()):
        return &"cell_occupied"
    for value: Variant in state.buildings.values():
        if (value as BuildingState).definition_id == &"transfer_depot":
            return &"transfer_depot_exists"
    var has_road := false
    for neighbor: HexCoord in coord.neighbors():
        if (
            state.map_state.contains(neighbor)
            and state.map_state.get_cell(neighbor).road_level >= RoadLevelDef.LEVEL_PATH
        ):
            has_road = true
            break
    if not has_road:
        return &"depot_not_adjacent_to_road"
    var main := state.get_building(state.main_warehouse_id)
    if main == null:
        return &"unknown_main_warehouse"
    if main.get_amount(WOOD) - main.get_outgoing_reserved(WOOD) < 10:
        return &"insufficient_wood"
    return &""


func _pipe_starts(state: SimulationState) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for building_id: int in _sorted_building_ids(state):
        var building := state.get_building(building_id)
        if not _building_has_port(state, building, UtilityPortDef.DIRECTION_OUTPUT, WATER):
            continue
        for neighbor: HexCoord in building.coord.neighbors():
            if _pipe_cell_available(state, neighbor) and not _has_coord(result, neighbor):
                result.append(neighbor)
    return result


func _pipe_extensions(
    state: SimulationState,
    path: Array[HexCoord]
) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for neighbor: HexCoord in path[-1].neighbors():
        if _pipe_cell_available(state, neighbor) and not _has_coord(path, neighbor):
            result.append(neighbor)
    return result


func _pipe_path_complete(state: SimulationState, path: Array[HexCoord]) -> bool:
    return (
        not path.is_empty()
        and _coord_has_adjacent_port(state, path[0], UtilityPortDef.DIRECTION_OUTPUT, WATER)
        and _coord_has_adjacent_port(state, path[-1], UtilityPortDef.DIRECTION_INPUT, WATER)
    )


func _coord_has_adjacent_port(
    state: SimulationState,
    coord: HexCoord,
    direction: StringName,
    commodity_id: StringName
) -> bool:
    for neighbor: HexCoord in coord.neighbors():
        var building_id := state.occupied_cells.get(neighbor.key(), 0) as int
        if building_id == 0:
            continue
        if _building_has_port(state, state.get_building(building_id), direction, commodity_id):
            return true
    return false


func _building_has_port(
    state: SimulationState,
    building: BuildingState,
    direction: StringName,
    commodity_id: StringName
) -> bool:
    if building == null:
        return false
    var definition := state.catalog.get_building(building.definition_id)
    if definition == null:
        return false
    for port: UtilityPortDef in definition.utility_ports:
        if port.direction == direction and port.commodity_id == commodity_id:
            return true
    return false


func _pipe_cell_available(state: SimulationState, coord: HexCoord) -> bool:
    return (
        state.map_state.contains(coord)
        and state.map_state.get_cell(coord).traversable
        and not state.occupied_cells.has(coord.key())
        and not state.utility_network.has_segment(coord)
    )


func _set_target(
    result: InteractionFeedbackState,
    coord: HexCoord,
    reason: StringName
) -> void:
    if coord == null:
        return
    result.target_state = (
        InteractionFeedbackState.VALID if reason.is_empty() else InteractionFeedbackState.INVALID
    )
    result.reason_code = reason


func _set_entity_target(
    result: InteractionFeedbackState,
    hover_id: int,
    valid: bool
) -> void:
    if hover_id <= 0:
        return
    result.target_state = InteractionFeedbackState.VALID if valid else InteractionFeedbackState.INVALID
    if not valid:
        result.reason_code = &"incompatible_link"


func _sorted_building_ids(state: SimulationState) -> Array[int]:
    var result: Array[int] = []
    for value: Variant in state.buildings.keys():
        result.append(value as int)
    result.sort()
    return result


func _has_coord(values: Array[HexCoord], expected: HexCoord) -> bool:
    for coord: HexCoord in values:
        if coord.equals(expected):
            return true
    return false


func _copy_coords(values: Array[HexCoord]) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for coord: HexCoord in values:
        result.append(HexCoord.new(coord.q, coord.r))
    return result
