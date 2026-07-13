class_name HexMapState
extends RefCounted

var width: int
var height: int
var _cells: Dictionary = {}
var _ordered_cells: Array[HexCellState] = []


func _init(p_width: int, p_height: int) -> void:
    assert(p_width > 0 and p_height > 0)
    width = p_width
    height = p_height

    for column in width:
        for row in height:
            var axial_r := row - (column - (column & 1)) / 2
            var coord := HexCoord.new(column, axial_r)
            var cell := HexCellState.new(coord)
            _cells[coord.key()] = cell
            _ordered_cells.append(cell)


func cell_count() -> int:
    return _cells.size()


func get_cells() -> Array[HexCellState]:
    return _ordered_cells.duplicate()


func contains(coord: HexCoord) -> bool:
    return coord != null and _cells.has(coord.key())


func get_cell(coord: HexCoord) -> HexCellState:
    if not contains(coord):
        return null
    return _cells[coord.key()] as HexCellState


func get_neighbors(coord: HexCoord) -> Array[HexCellState]:
    var result: Array[HexCellState] = []
    if not contains(coord):
        return result

    for neighbor_coord in coord.neighbors():
        var cell := get_cell(neighbor_coord)
        if cell != null:
            result.append(cell)
    return result


func set_movement_cost(coord: HexCoord, cost: int) -> bool:
    var cell := get_cell(coord)
    if cell == null or cost < 1:
        return false
    cell.movement_cost = cost
    return true
