class_name HexGridView
extends Node2D

signal hex_selected(coord: HexCoord)

const CELL_COLOR_A := Color("#34493d")
const CELL_COLOR_B := Color("#3d5345")
const OUTLINE_COLOR := Color("#788777")
const SELECTED_COLOR := Color("#d69a4a")

var _map_state: HexMapState
var _layout: HexLayout
var _selected_coord: HexCoord


func configure(map_state: HexMapState, layout: HexLayout) -> void:
    _map_state = map_state
    _layout = layout
    queue_redraw()


func select_at_local_position(local_position: Vector2) -> bool:
    if _map_state == null or _layout == null:
        return false

    var coord := _layout.pixel_to_coord(local_position)
    if not _map_state.contains(coord):
        return false

    _selected_coord = coord
    queue_redraw()
    hex_selected.emit(coord)
    return true


func get_selected_coord() -> HexCoord:
    return _selected_coord


func get_world_rect() -> Rect2:
    if _map_state == null or _layout == null:
        return Rect2()

    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    for q in _map_state.width:
        for r in _map_state.height:
            for point in _layout.polygon_corners(HexCoord.new(q, r)):
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

    for q in _map_state.width:
        for r in _map_state.height:
            var coord := HexCoord.new(q, r)
            var points := _layout.polygon_corners(coord)
            var fill := CELL_COLOR_A if (q + r) % 2 == 0 else CELL_COLOR_B
            draw_colored_polygon(points, fill)
            draw_polyline(_closed_polygon(points), OUTLINE_COLOR, 1.0, true)

            if _selected_coord != null and _selected_coord.equals(coord):
                draw_polyline(_closed_polygon(points), SELECTED_COLOR, 4.0, true)


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
    var result := points.duplicate()
    result.append(points[0])
    return result
