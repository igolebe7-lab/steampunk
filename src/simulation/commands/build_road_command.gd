class_name BuildRoadCommand
extends SimulationCommand

const TYPE := SimulationCommand.BUILD_ROAD

var coords: Array[HexCoord]:
    get:
        return _copy_coords(_coords)

var _coords: Array[HexCoord] = []


func _init(p_target_tick: int, p_sequence: int, p_coords: Array) -> void:
    super(TYPE, p_target_tick, p_sequence)
    _coords = _copy_coords(p_coords)


func snapshot() -> SimulationCommand:
    return BuildRoadCommand.new(target_tick, sequence, _coords)


static func _copy_coords(source: Array) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for value: Variant in source:
        var coord := value as HexCoord
        result.append(null if coord == null else HexCoord.new(coord.q, coord.r))
    return result
