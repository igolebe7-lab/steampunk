class_name BuildingState
extends RefCounted

var id: int:
    get:
        return _id
var definition_id: StringName:
    get:
        return _definition_id
var coord: HexCoord:
    get:
        return _coord
var priority: int

var _id: int
var _definition_id: StringName
var _coord: HexCoord


func _init(
    p_id: int,
    p_definition_id: StringName,
    p_coord: HexCoord,
    p_priority: int
) -> void:
    _id = p_id
    _definition_id = p_definition_id
    _coord = p_coord
    priority = p_priority
