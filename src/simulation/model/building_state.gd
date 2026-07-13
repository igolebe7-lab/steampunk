class_name BuildingState
extends RefCounted

var id: int
var definition_id: StringName
var coord: HexCoord
var priority: int


func _init(
    p_id: int,
    p_definition_id: StringName,
    p_coord: HexCoord,
    p_priority: int
) -> void:
    id = p_id
    definition_id = p_definition_id
    coord = p_coord
    priority = p_priority
