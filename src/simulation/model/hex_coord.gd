class_name HexCoord
extends RefCounted

const DIRECTIONS := [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

var q: int:
    get:
        return _q
var r: int:
    get:
        return _r
var s: int:
    get:
        return -_q - _r

var _q: int
var _r: int


func _init(p_q: int = 0, p_r: int = 0) -> void:
    _q = p_q
    _r = p_r


func neighbor(direction: int) -> HexCoord:
    assert(direction >= 0 and direction < DIRECTIONS.size())
    var offset: Vector2i = DIRECTIONS[direction]
    return HexCoord.new(q + offset.x, r + offset.y)


func neighbors() -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for direction in DIRECTIONS.size():
        result.append(neighbor(direction))
    return result


func distance_to(other: HexCoord) -> int:
    return int((absi(q - other.q) + absi(r - other.r) + absi(s - other.s)) / 2)


func key() -> StringName:
    return StringName("%d:%d" % [q, r])


func equals(other: HexCoord) -> bool:
    return other != null and q == other.q and r == other.r
