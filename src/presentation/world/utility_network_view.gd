class_name UtilityNetworkView
extends Node2D

const WATER_COLOR := Color(0.20, 0.72, 0.92, 0.95)

var _layout: HexLayout
var _state: SimulationState
var _topology_revision: int = -1
var _centers: Dictionary = {}
var _coords: Dictionary = {}
var _connections: Array[PackedVector2Array] = []
var _masks: Dictionary = {}
var _pipe_preview: Dictionary = {}
var _rebuild_count: int = 0


func configure(state: SimulationState, layout: HexLayout) -> void:
    _state = state
    _layout = layout
    _topology_revision = -1
    _rebuild(state)


func capture_tick(state: SimulationState) -> void:
    _state = state
    if state.utility_network.topology_revision != _topology_revision:
        _rebuild(state)


func get_segment_visual_count() -> int:
    return _centers.size()


func get_rebuild_count() -> int:
    return _rebuild_count


func get_cached_connection_mask(coord: HexCoord) -> int:
    return _masks.get(coord.key(), 0) as int


func set_pipe_preview(coords: Array[HexCoord]) -> void:
    var next: Dictionary = {}
    for coord: HexCoord in coords:
        if coord != null:
            next[coord.key()] = &"water"
    if next == _pipe_preview:
        return
    _pipe_preview = next
    if _state != null:
        _rebuild(_state)


func hit_test_segment(local_position: Vector2, radius: float = 13.0) -> HexCoord:
    var keys := _centers.keys()
    keys.sort()
    for key: Variant in keys:
        if (_centers[key] as Vector2).distance_to(local_position) <= radius:
            var coord := _coords[key] as HexCoord
            return HexCoord.new(coord.q, coord.r)
    return null


func _rebuild(state: SimulationState) -> void:
    _centers.clear()
    _coords.clear()
    _connections.clear()
    _masks.clear()
    if _layout == null:
        return
    var keys := state.utility_network.segments.keys()
    keys.sort()
    for key: Variant in keys:
        var segment := state.utility_network.segments[key] as UtilitySegmentState
        _centers[key] = _layout.coord_to_pixel(segment.coord)
        _coords[key] = HexCoord.new(segment.coord.q, segment.coord.r)
    for key: Variant in _pipe_preview.keys():
        if not _centers.has(key):
            var parts := String(key).split(":")
            var coord := HexCoord.new(parts[0].to_int(), parts[1].to_int())
            _centers[key] = _layout.coord_to_pixel(coord)
            _coords[key] = coord
    var all_keys := _centers.keys()
    all_keys.sort()
    for key: Variant in all_keys:
        var coord := _coords[key] as HexCoord
        var mask := ConnectionTopology.pipe_mask(state, coord, _pipe_preview)
        _masks[key] = mask
        var center := _centers[key] as Vector2
        for direction in HexCoord.DIRECTIONS.size():
            if ConnectionTopology.has_direction(mask, direction):
                _connections.append(PackedVector2Array([
                    center,
                    center.lerp(_layout.coord_to_pixel(coord.neighbor(direction)), 0.52),
                ]))
    _topology_revision = state.utility_network.topology_revision
    _rebuild_count += 1
    queue_redraw()


func _draw() -> void:
    for connection: PackedVector2Array in _connections:
        draw_line(connection[0], connection[1], WATER_COLOR.darkened(0.25), 8.0, true)
        draw_line(connection[0], connection[1], WATER_COLOR, 3.0, true)
    for center_value: Variant in _centers.values():
        draw_circle(center_value as Vector2, 7.0, WATER_COLOR.darkened(0.2))
        draw_circle(center_value as Vector2, 3.0, Color(0.70, 0.94, 1.0, 1.0))
