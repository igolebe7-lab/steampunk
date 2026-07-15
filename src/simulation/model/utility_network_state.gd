class_name UtilityNetworkState
extends RefCounted

var segments: Dictionary = {}
var topology_revision: int = 0
var pipe_water_delivered: int = 0
var manual_water_delivered: int = 0


func has_segment(coord: HexCoord) -> bool:
    return coord != null and segments.has(coord.key())


func get_segment(coord: HexCoord) -> UtilitySegmentState:
    return null if coord == null else segments.get(coord.key()) as UtilitySegmentState


func add_segment(coord: HexCoord, commodity_id: StringName) -> bool:
    if coord == null or commodity_id.is_empty() or has_segment(coord):
        return false
    segments[coord.key()] = UtilitySegmentState.new(coord, commodity_id)
    return true


func remove_segment(coord: HexCoord) -> bool:
    if not has_segment(coord):
        return false
    segments.erase(coord.key())
    return true
