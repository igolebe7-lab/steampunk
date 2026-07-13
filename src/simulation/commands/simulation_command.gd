class_name SimulationCommand
extends RefCounted

const SET_BUILDING_PRIORITY := &"set_building_priority"

var type: StringName
var target_tick: int
var sequence: int
var building_id: int
var priority: int


func _init(
    p_type: StringName,
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_priority: int
) -> void:
    type = p_type
    target_tick = p_target_tick
    sequence = p_sequence
    building_id = p_building_id
    priority = p_priority


static func set_building_priority(
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_priority: int
) -> SimulationCommand:
    return SimulationCommand.new(
        SET_BUILDING_PRIORITY,
        p_target_tick,
        p_sequence,
        p_building_id,
        p_priority
    )
