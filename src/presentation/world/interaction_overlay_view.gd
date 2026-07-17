class_name InteractionOverlayView
extends Node2D

const HOVER_COLOR := Color(0.91, 0.86, 0.74, 0.85)
const SELECTED_COLOR := Color(0.84, 0.60, 0.29, 0.95)
const VALID_COLOR := Color(0.27, 0.78, 0.72, 0.82)
const INVALID_COLOR := Color(0.82, 0.25, 0.23, 0.90)
const PREVIEW_COLOR := Color(0.36, 0.84, 0.80, 0.52)

var _state: SimulationState
var _layout: HexLayout
var _feedback: InteractionFeedbackState
var _signature := ""
var _rebuild_count := 0
var _hover_visual_count := 0
var _selection_visual_count := 0
var _target_visual_count := 0
var _preview_visual_count := 0
var _target_state: StringName = InteractionFeedbackState.NEUTRAL


func configure(state: SimulationState, layout: HexLayout) -> void:
    _state = state
    _layout = layout
    _signature = ""
    queue_redraw()


func capture_tick(state: SimulationState) -> void:
    _state = state


func present(feedback: InteractionFeedbackState) -> void:
    if feedback == null:
        return
    var next_signature := _feedback_signature(feedback)
    if next_signature == _signature:
        return
    _signature = next_signature
    _feedback = feedback
    _hover_visual_count = 1 if feedback.hover_coord != null or feedback.hover_id > 0 else 0
    _selection_visual_count = (
        1 if feedback.selected_coord != null or feedback.selected_id > 0 else 0
    )
    _target_visual_count = (
        feedback.highlight_coords.size() + feedback.highlight_entity_ids.size()
    )
    if feedback.target_state == InteractionFeedbackState.INVALID and feedback.hover_coord != null:
        _target_visual_count += 1
    _preview_visual_count = feedback.preview_coords.size()
    _target_state = feedback.target_state
    _rebuild_count += 1
    queue_redraw()


func get_hover_visual_count() -> int:
    return _hover_visual_count


func get_selection_visual_count() -> int:
    return _selection_visual_count


func get_target_visual_count() -> int:
    return _target_visual_count


func get_preview_visual_count() -> int:
    return _preview_visual_count


func get_target_state() -> StringName:
    return _target_state


func get_rebuild_count() -> int:
    return _rebuild_count


func _draw() -> void:
    if _state == null or _layout == null or _feedback == null:
        return
    for coord: HexCoord in _feedback.highlight_coords:
        _draw_hex_target(coord, VALID_COLOR, InteractionFeedbackState.VALID)
    for entity_id: int in _feedback.highlight_entity_ids:
        var building := _state.get_building(entity_id)
        if building != null:
            _draw_hex_target(building.coord, VALID_COLOR, InteractionFeedbackState.VALID)
    for coord: HexCoord in _feedback.preview_coords:
        draw_colored_polygon(
            _layout.polygon_corners(coord),
            Color(PREVIEW_COLOR, PREVIEW_COLOR.a * 0.32)
        )
    if _feedback.hover_coord != null:
        if _feedback.target_state == InteractionFeedbackState.INVALID:
            _draw_hex_target(
                _feedback.hover_coord,
                INVALID_COLOR,
                InteractionFeedbackState.INVALID
            )
        else:
            var hover_color := (
                VALID_COLOR
                if _feedback.target_state == InteractionFeedbackState.VALID
                else HOVER_COLOR
            )
            _draw_outline(_feedback.hover_coord, hover_color, 2.0)
    if _feedback.selected_coord != null:
        _draw_outline(_feedback.selected_coord, SELECTED_COLOR, 4.0)
        _draw_outline(_feedback.selected_coord, SELECTED_COLOR.lightened(0.25), 1.5, 5.0)


func _draw_hex_target(coord: HexCoord, color: Color, state: StringName) -> void:
    draw_colored_polygon(_layout.polygon_corners(coord), Color(color, color.a * 0.16))
    _draw_outline(coord, color, 3.0)
    var center := _layout.coord_to_pixel(coord)
    if state == InteractionFeedbackState.INVALID:
        draw_line(center + Vector2(-6.0, -6.0), center + Vector2(6.0, 6.0), color, 3.0, true)
        draw_line(center + Vector2(6.0, -6.0), center + Vector2(-6.0, 6.0), color, 3.0, true)
    else:
        draw_circle(center, 4.0, color)


func _draw_outline(
    coord: HexCoord,
    color: Color,
    width: float,
    inset: float = 0.0
) -> void:
    var points := _layout.polygon_corners(coord)
    if inset > 0.0:
        var center := _layout.coord_to_pixel(coord)
        for index in points.size():
            points[index] = points[index].move_toward(center, inset)
    points.append(points[0])
    draw_polyline(points, color, width, true)


func _feedback_signature(feedback: InteractionFeedbackState) -> String:
    var parts := PackedStringArray([
        String(feedback.mode),
        String(feedback.target_state),
        String(feedback.reason_code),
        String(feedback.hover_kind),
        str(feedback.hover_id),
        _coord_key(feedback.hover_coord),
        String(feedback.selected_kind),
        str(feedback.selected_id),
        _coord_key(feedback.selected_coord),
        str(feedback.cost),
        str(feedback.can_confirm),
    ])
    var highlight_keys := PackedStringArray()
    for coord: HexCoord in feedback.highlight_coords:
        highlight_keys.append(String(coord.key()))
    highlight_keys.sort()
    parts.append("h=%s" % ",".join(highlight_keys))
    var entity_ids := feedback.highlight_entity_ids.duplicate()
    entity_ids.sort()
    var entity_keys := PackedStringArray()
    for entity_id: int in entity_ids:
        entity_keys.append(str(entity_id))
    parts.append("e=%s" % ",".join(entity_keys))
    var preview_keys := PackedStringArray()
    for coord: HexCoord in feedback.preview_coords:
        preview_keys.append(String(coord.key()))
    parts.append("p=%s" % ",".join(preview_keys))
    return "|".join(parts)


func _coord_key(coord: HexCoord) -> String:
    return "" if coord == null else String(coord.key())
