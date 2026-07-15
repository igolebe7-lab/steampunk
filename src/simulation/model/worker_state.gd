class_name WorkerState
extends RefCounted

const IDLE := &"idle"
const ASSIGNED := &"assigned"
const TO_SOURCE := &"to_source"
const LOADING := &"loading"
const AWAITING_DESTINATION_PATH := &"awaiting_destination_path"
const TO_DESTINATION := &"to_destination"
const UNLOADING := &"unloading"
const BLOCKED := &"blocked"

var id: int
var coord: HexCoord
var previous_coord: HexCoord
var segment_target: HexCoord
var segment_progress: int = 0
var segment_duration: int = 0
var route: Array[HexCoord] = []
var route_index: int = 0
var job_id: int = 0
var link_id: int = 0
var cargo_resource_id: StringName
var action: StringName = IDLE
var wait_reason: StringName = &"no_job"
var wait_ticks: int = 0
var operation_progress: int = 0


func _init(p_id: int, p_coord: HexCoord) -> void:
    id = p_id
    coord = p_coord
    previous_coord = HexCoord.new(p_coord.q, p_coord.r)
