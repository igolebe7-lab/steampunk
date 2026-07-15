class_name HexGridView
extends Node2D

signal hex_selected(coord: HexCoord)
signal local_position_selected(local_position: Vector2)

const CELL_COLOR_A := Color("#34493d")
const CELL_COLOR_B := Color("#3d5345")
const OUTLINE_COLOR := Color("#788777")
const SELECTED_COLOR := Color("#d69a4a")
const PATH_COLOR := Color("#b69a69")
const ROAD_COLOR := Color("#d0b072")
const HEAT_COLOR := Color("#d95f45")

var _map_state: HexMapState
var _layout: HexLayout
var _selected_coord: HexCoord
var _heat_overlay: Dictionary = {}
var _cell_visuals: Array[Dictionary] = []


func configure(map_state: HexMapState, layout: HexLayout) -> void:
    _map_state = map_state
    _layout = layout
    _rebuild_cache()
    queue_redraw()


func capture_tick(map_state: HexMapState, heat_overlay: Variant = null) -> void:
    _map_state = map_state
    if heat_overlay is Dictionary:
        _heat_overlay = (heat_overlay as Dictionary).duplicate()
    _rebuild_cache()
    queue_redraw()


func set_heat_overlay(values: Dictionary) -> void:
    _heat_overlay = values.duplicate()
    _rebuild_cache()
    queue_redraw()


func get_cached_road_level(coord: HexCoord) -> int:
    for visual: Dictionary in _cell_visuals:
        if (visual[&"coord"] as HexCoord).equals(coord):
            return visual[&"road_level"] as int
    return -1


func get_cached_heat(coord: HexCoord) -> float:
    for visual: Dictionary in _cell_visuals:
        if (visual[&"coord"] as HexCoord).equals(coord):
            return visual[&"heat"] as float
    return 0.0


func select_at_local_position(local_position: Vector2) -> bool:
    if _map_state == null or _layout == null:
        return false

    var coord := _layout.pixel_to_coord(local_position)
    if not _map_state.contains(coord):
        return false

    _selected_coord = coord
    queue_redraw()
    local_position_selected.emit(local_position)
    hex_selected.emit(coord)
    return true


func get_selected_coord() -> HexCoord:
    return _selected_coord


func get_world_rect() -> Rect2:
    if _map_state == null or _layout == null:
        return Rect2()

    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    for cell in _map_state.get_cells():
        for point in _layout.polygon_corners(cell.coord):
            minimum.x = minf(minimum.x, point.x)
            minimum.y = minf(minimum.y, point.y)
            maximum.x = maxf(maximum.x, point.x)
            maximum.y = maxf(maximum.y, point.y)
    return Rect2(minimum + position, maximum - minimum)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            if select_at_local_position(to_local(get_global_mouse_position())):
                get_viewport().set_input_as_handled()


func _draw() -> void:
    if _map_state == null or _layout == null:
        return

    for visual: Dictionary in _cell_visuals:
        var coord := visual[&"coord"] as HexCoord
        var points := visual[&"points"] as PackedVector2Array
        var fill := visual[&"fill"] as Color
        draw_colored_polygon(points, fill)
        var heat := visual[&"heat"] as float
        if heat > 0.0:
            draw_colored_polygon(points, Color(HEAT_COLOR, clampf(heat, 0.0, 1.0) * 0.45))
        draw_polyline(_closed_polygon(points), OUTLINE_COLOR, 1.0, true)

        var road_level := visual[&"road_level"] as int
        if road_level > RoadLevelDef.LEVEL_OPEN_GROUND:
            var color := PATH_COLOR if road_level == RoadLevelDef.LEVEL_PATH else ROAD_COLOR
            var width := 5.0 if road_level == RoadLevelDef.LEVEL_PATH else 9.0
            draw_circle(_layout.coord_to_pixel(coord), width * 0.55, color)
            for segment: PackedVector2Array in visual[&"road_segments"]:
                draw_line(segment[0], segment[1], color, width, true)

        if _selected_coord != null and _selected_coord.equals(coord):
            draw_polyline(_closed_polygon(points), SELECTED_COLOR, 4.0, true)


func _rebuild_cache() -> void:
    _cell_visuals.clear()
    if _map_state == null or _layout == null:
        return
    for cell: HexCellState in _map_state.get_cells():
        var coord := cell.coord
        var road_segments: Array[PackedVector2Array] = []
        for neighbor: HexCoord in coord.neighbors():
            if _map_state.contains(neighbor):
                road_segments.append(PackedVector2Array([
                    _layout.coord_to_pixel(coord),
                    _layout.coord_to_pixel(coord).lerp(_layout.coord_to_pixel(neighbor), 0.48),
                ]))
        _cell_visuals.append({
            &"coord": coord,
            &"points": _layout.polygon_corners(coord),
            &"fill": CELL_COLOR_A if (coord.q + coord.r) % 2 == 0 else CELL_COLOR_B,
            &"road_level": cell.road_level,
            &"road_segments": road_segments,
            &"heat": float(_heat_overlay.get(coord.key(), 0.0)),
        })


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
    var result := points.duplicate()
    result.append(points[0])
    return result
