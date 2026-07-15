class_name DepotCommand
extends SimulationCommand

var coord: HexCoord:
    get:
        return null if _coord == null else HexCoord.new(_coord.q, _coord.r)
var building_id: int:
    get:
        return _building_id

var _coord: HexCoord
var _building_id: int


func _init(
    p_type: StringName,
    p_target_tick: int,
    p_sequence: int,
    p_coord: HexCoord = null,
    p_building_id: int = 0
) -> void:
    super(p_type, p_target_tick, p_sequence)
    _coord = null if p_coord == null else HexCoord.new(p_coord.q, p_coord.r)
    _building_id = p_building_id


static func place(p_target_tick: int, p_sequence: int, p_coord: HexCoord) -> DepotCommand:
    return DepotCommand.new(SimulationCommand.PLACE_DEPOT, p_target_tick, p_sequence, p_coord)


static func demolish(p_target_tick: int, p_sequence: int, p_building_id: int) -> DepotCommand:
    return DepotCommand.new(
        SimulationCommand.DEMOLISH_DEPOT,
        p_target_tick,
        p_sequence,
        null,
        p_building_id
    )


func snapshot() -> SimulationCommand:
    return DepotCommand.new(type, target_tick, sequence, _coord, building_id)
