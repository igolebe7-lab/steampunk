class_name ScenarioLoadResult
extends RefCounted

var state: SimulationState
var errors: Array[StringName]


func _init(p_state: SimulationState, p_errors: Array[StringName]) -> void:
    state = p_state
    errors = p_errors


func is_success() -> bool:
    return state != null and errors.is_empty()
