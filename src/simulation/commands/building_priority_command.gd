class_name BuildingPriorityCommand
extends SimulationCommand

var building_id: int:
    get:
        return _building_id
var priority: int:
    get:
        return _priority

var _building_id: int
var _priority: int


func _init(
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_priority: int
) -> void:
    super(SimulationCommand.SET_BUILDING_PRIORITY, p_target_tick, p_sequence)
    _building_id = p_building_id
    _priority = p_priority


func snapshot() -> SimulationCommand:
    return BuildingPriorityCommand.new(target_tick, sequence, building_id, priority)
