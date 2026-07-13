class_name SimulationCommand
extends RefCounted

const SET_BUILDING_PRIORITY := &"set_building_priority"

var id: StringName:
    get:
        return _id
var type: StringName:
    get:
        return _type
var target_tick: int:
    get:
        return _target_tick
var sequence: int:
    get:
        return _sequence
var building_id: int:
    get:
        return _building_id
var priority: int:
    get:
        return _priority

var _id: StringName
var _type: StringName
var _target_tick: int
var _sequence: int
var _building_id: int
var _priority: int


func _init(
    p_type: StringName,
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_priority: int
) -> void:
    _id = StringName("%d:%d" % [p_target_tick, p_sequence])
    _type = p_type
    _target_tick = p_target_tick
    _sequence = p_sequence
    _building_id = p_building_id
    _priority = p_priority


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


func snapshot() -> SimulationCommand:
    return SimulationCommand.new(type, target_tick, sequence, building_id, priority)
