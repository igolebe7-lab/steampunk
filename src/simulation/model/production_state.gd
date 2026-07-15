class_name ProductionState
extends RefCounted

const LOCKED := &"locked"
const WAITING_INPUTS := &"waiting_inputs"
const RUNNING := &"running"
const BLOCKED := &"blocked"
const COMPLETED := &"completed"

var building_id: int
var recipe_id: StringName
var status: StringName = LOCKED
var progress_ticks: int = 0
var completed_cycles: int = 0
var heat_level: int = 0
var cooling_ticks: int = 0
var blocked_reason: StringName = &""
var linked_building_id: int = 0


func _init(p_building_id: int, p_recipe_id: StringName) -> void:
    building_id = p_building_id
    recipe_id = p_recipe_id
