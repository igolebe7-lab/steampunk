class_name PathResult
extends RefCounted

var path: Array[HexCoord]
var cost: int


func _init(p_path: Array[HexCoord] = [], p_cost: int = 0) -> void:
    path = p_path
    cost = p_cost


func is_success() -> bool:
    return not path.is_empty()


func keys() -> Array[StringName]:
    var result: Array[StringName] = []
    for coord in path:
        result.append(coord.key())
    return result
