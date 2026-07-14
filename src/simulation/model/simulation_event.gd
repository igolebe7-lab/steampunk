class_name SimulationEvent
extends RefCounted

var code: StringName
var tick: int
var entity_id: int
var job_id: int
var resource_id: StringName


func _init(p_code: StringName, p_tick: int, p_entity_id: int = 0, p_job_id: int = 0, p_resource_id: StringName = &"") -> void:
    code = p_code
    tick = p_tick
    entity_id = p_entity_id
    job_id = p_job_id
    resource_id = p_resource_id
