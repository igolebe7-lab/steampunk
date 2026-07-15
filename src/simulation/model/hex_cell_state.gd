class_name HexCellState
extends RefCounted

var coord: HexCoord
var traversable: bool = true
var movement_cost: int = 1
var road_level: int = RoadLevelDef.LEVEL_OPEN_GROUND


func _init(p_coord: HexCoord) -> void:
    coord = p_coord
