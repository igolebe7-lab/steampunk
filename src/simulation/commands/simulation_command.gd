class_name SimulationCommand
extends RefCounted

const SET_BUILDING_PRIORITY := &"set_building_priority"
const BUILD_ROAD := &"build_road"
const PLACE_DEPOT := &"place_depot"
const DEMOLISH_DEPOT := &"demolish_depot"
const CREATE_LINK := &"create_link"
const REMOVE_LINK := &"remove_link"
const RESET_AUTOMATIC_LINK := &"reset_automatic_link"
const SET_LINK_SETTINGS := &"set_link_settings"
const SET_DISPATCH_POLICY := &"set_dispatch_policy"
const BUILD_PIPE := &"build_pipe"
const REMOVE_PIPE := &"remove_pipe"

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
var _id: StringName
var _type: StringName
var _target_tick: int
var _sequence: int


func _init(
    p_type: StringName,
    p_target_tick: int,
    p_sequence: int
) -> void:
    _id = StringName("%d:%d" % [p_target_tick, p_sequence])
    _type = p_type
    _target_tick = p_target_tick
    _sequence = p_sequence


static func set_building_priority(
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_priority: int
) -> SimulationCommand:
    return BuildingPriorityCommand.new(p_target_tick, p_sequence, p_building_id, p_priority)


func snapshot() -> SimulationCommand:
    return SimulationCommand.new(type, target_tick, sequence)
