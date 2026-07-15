class_name PipeCommand
extends SimulationCommand

const BUILD := &"build"
const REMOVE := &"remove"

var operation: StringName
var coords: Array[HexCoord]:
    get:
        return _copy_coords(_coords)

var _coords: Array[HexCoord] = []


func _init(
    p_type: StringName,
    p_operation: StringName,
    p_target_tick: int,
    p_sequence: int,
    p_coords: Array
) -> void:
    super(p_type, p_target_tick, p_sequence)
    operation = p_operation
    _coords = _copy_coords(p_coords)


static func build(p_target_tick: int, p_sequence: int, p_coords: Array) -> PipeCommand:
    return PipeCommand.new(
        SimulationCommand.BUILD_PIPE,
        BUILD,
        p_target_tick,
        p_sequence,
        p_coords
    )


static func remove(p_target_tick: int, p_sequence: int, p_coords: Array) -> PipeCommand:
    return PipeCommand.new(
        SimulationCommand.REMOVE_PIPE,
        REMOVE,
        p_target_tick,
        p_sequence,
        p_coords
    )


func snapshot() -> SimulationCommand:
    return PipeCommand.new(type, operation, target_tick, sequence, _coords)


static func _copy_coords(source: Array) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for value: Variant in source:
        var coord := value as HexCoord
        result.append(null if coord == null else HexCoord.new(coord.q, coord.r))
    return result
