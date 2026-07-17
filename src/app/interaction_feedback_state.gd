class_name InteractionFeedbackState
extends RefCounted

const NEUTRAL := &"neutral"
const VALID := &"valid"
const INVALID := &"invalid"

var mode: StringName = ToolController.INSPECT
var hint_key: StringName = &"ui.hint.inspect"
var target_state: StringName = NEUTRAL
var reason_code: StringName = &""
var hover_kind: StringName = &""
var hover_id: int = 0
var hover_coord: HexCoord
var selected_kind: StringName = &""
var selected_id: int = 0
var selected_coord: HexCoord
var highlight_coords: Array[HexCoord] = []
var highlight_entity_ids: Array[int] = []
var preview_coords: Array[HexCoord] = []
var cost: int = 0
var can_confirm: bool = false
var can_cancel: bool = false


func set_hover(kind: StringName, entity_id: int, coord: HexCoord) -> void:
    hover_kind = kind
    hover_id = entity_id
    hover_coord = _copy_coord(coord)


func set_selection(kind: StringName, entity_id: int, coord: HexCoord) -> void:
    selected_kind = kind
    selected_id = entity_id
    selected_coord = _copy_coord(coord)


func set_highlight_coords(values: Array[HexCoord]) -> void:
    highlight_coords = _copy_coords(values)


func set_preview_coords(values: Array[HexCoord]) -> void:
    preview_coords = _copy_coords(values)


func _copy_coords(values: Array[HexCoord]) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for coord: HexCoord in values:
        result.append(_copy_coord(coord))
    return result


func _copy_coord(coord: HexCoord) -> HexCoord:
    return null if coord == null else HexCoord.new(coord.q, coord.r)
