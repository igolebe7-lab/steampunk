class_name UtilitySegmentState
extends RefCounted

var coord: HexCoord
var commodity_id: StringName
var component_id: StringName = &""


func _init(p_coord: HexCoord, p_commodity_id: StringName) -> void:
    coord = HexCoord.new(p_coord.q, p_coord.r)
    commodity_id = p_commodity_id
