class_name UtilityNetworkView
extends Node2D

const WATER_COLOR := Color(0.20, 0.72, 0.92, 0.95)

var _layout: HexLayout
var _topology_revision: int = -1
var _centers: Dictionary = {}
var _coords: Dictionary = {}
var _connections: Array[PackedVector2Array] = []
var _rebuild_count: int = 0


func configure(state: SimulationState, layout: HexLayout) -> void:
    _layout = layout
    _topology_revision = -1
    _rebuild(state)


func capture_tick(state: SimulationState) -> void:
    if state.utility_network.topology_revision != _topology_revision:
        _rebuild(state)


func get_segment_visual_count() -> int:
    return _centers.size()


func get_rebuild_count() -> int:
    return _rebuild_count


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
    if _layout == null:
        return
    var keys := state.utility_network.segments.keys()
    keys.sort()
    for key: Variant in keys:
        var segment := state.utility_network.segments[key] as UtilitySegmentState
        _centers[key] = _layout.coord_to_pixel(segment.coord)
        _coords[key] = HexCoord.new(segment.coord.q, segment.coord.r)
    for key: Variant in keys:
        var segment := state.utility_network.segments[key] as UtilitySegmentState
        for neighbor: HexCoord in segment.coord.neighbors():
            var neighbor_key := neighbor.key()
            if String(key) < String(neighbor_key) and _centers.has(neighbor_key):
                _connections.append(PackedVector2Array([_centers[key], _centers[neighbor_key]]))
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
