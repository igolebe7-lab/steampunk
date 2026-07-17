class_name ConnectionTopology
extends RefCounted


static func road_mask(
    map_state: HexMapState,
    coord: HexCoord,
    preview: Dictionary = {}
) -> int:
    if map_state == null or coord == null:
        return 0
    var mask := 0
    for direction in HexCoord.DIRECTIONS.size():
        var neighbor := coord.neighbor(direction)
        var connected := preview.has(neighbor.key())
        if map_state.contains(neighbor):
            connected = connected or (
                map_state.get_cell(neighbor).road_level >= RoadLevelDef.LEVEL_PATH
            )
        if connected:
            mask |= 1 << direction
    return mask


static func pipe_mask(
    state: SimulationState,
    coord: HexCoord,
    preview: Dictionary = {}
) -> int:
    if state == null or coord == null:
        return 0
    var commodity_id := _pipe_commodity(state, coord, preview)
    if commodity_id.is_empty():
        return 0
    var mask := 0
    for direction in HexCoord.DIRECTIONS.size():
        var neighbor := coord.neighbor(direction)
        if (
            _has_compatible_segment(state, neighbor, commodity_id, preview)
            or _has_compatible_port(state, neighbor, commodity_id)
        ):
            mask |= 1 << direction
    return mask


static func has_direction(mask: int, direction: int) -> bool:
    return direction >= 0 and direction < HexCoord.DIRECTIONS.size() and (
        mask & (1 << direction)
    ) != 0


static func _pipe_commodity(
    state: SimulationState,
    coord: HexCoord,
    preview: Dictionary
) -> StringName:
    var segment := state.utility_network.get_segment(coord)
    if segment != null:
        return segment.commodity_id
    var preview_value: Variant = preview.get(coord.key(), &"")
    if preview_value is StringName:
        return preview_value as StringName
    if preview_value is String:
        return StringName(preview_value as String)
    if preview_value == true:
        return &"water"
    return &""


static func _has_compatible_segment(
    state: SimulationState,
    coord: HexCoord,
    commodity_id: StringName,
    preview: Dictionary
) -> bool:
    var segment := state.utility_network.get_segment(coord)
    if segment != null:
        return segment.commodity_id == commodity_id
    if not preview.has(coord.key()):
        return false
    var preview_value: Variant = preview[coord.key()]
    if preview_value is bool:
        return preview_value as bool
    if preview_value is StringName:
        return (preview_value as StringName) == commodity_id
    if preview_value is String:
        return StringName(preview_value as String) == commodity_id
    return false


static func _has_compatible_port(
    state: SimulationState,
    coord: HexCoord,
    commodity_id: StringName
) -> bool:
    var building_id := state.occupied_cells.get(coord.key(), 0) as int
    if building_id == 0:
        return false
    var building := state.get_building(building_id)
    if building == null:
        return false
    var definition := state.catalog.get_building(building.definition_id)
    if definition == null:
        return false
    for port: UtilityPortDef in definition.utility_ports:
        if port.commodity_id == commodity_id:
            return true
    return false
