class_name HexLayout
extends RefCounted

const SQRT_3 := 1.7320508075688772

var hex_size: float
var origin: Vector2


func _init(p_hex_size: float = 32.0, p_origin: Vector2 = Vector2.ZERO) -> void:
    assert(p_hex_size > 0.0)
    hex_size = p_hex_size
    origin = p_origin


func coord_to_pixel(coord: HexCoord) -> Vector2:
    return origin + Vector2(
        hex_size * 1.5 * coord.q,
        hex_size * SQRT_3 * (coord.r + coord.q * 0.5)
    )


func pixel_to_coord(pixel: Vector2) -> HexCoord:
    var local := pixel - origin
    var fractional_q := (2.0 / 3.0 * local.x) / hex_size
    var fractional_r := (-1.0 / 3.0 * local.x + SQRT_3 / 3.0 * local.y) / hex_size
    return _round_axial(fractional_q, fractional_r)


func polygon_corners(coord: HexCoord) -> PackedVector2Array:
    var center := coord_to_pixel(coord)
    var points := PackedVector2Array()
    for index in 6:
        var angle := deg_to_rad(60.0 * index)
        points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
    return points


func _round_axial(fractional_q: float, fractional_r: float) -> HexCoord:
    var fractional_s := -fractional_q - fractional_r
    var rounded_q := roundi(fractional_q)
    var rounded_r := roundi(fractional_r)
    var rounded_s := roundi(fractional_s)
    var q_difference := absf(rounded_q - fractional_q)
    var r_difference := absf(rounded_r - fractional_r)
    var s_difference := absf(rounded_s - fractional_s)

    if q_difference > r_difference and q_difference > s_difference:
        rounded_q = -rounded_r - rounded_s
    elif r_difference > s_difference:
        rounded_r = -rounded_q - rounded_s

    return HexCoord.new(rounded_q, rounded_r)
