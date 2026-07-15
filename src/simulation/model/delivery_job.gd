class_name DeliveryJob
extends RefCounted

const QUEUED := &"queued"
const ASSIGNED := &"assigned"
const TO_SOURCE := &"to_source"
const LOADING := &"loading"
const AWAITING_DESTINATION_PATH := &"awaiting_destination_path"
const TO_DESTINATION := &"to_destination"
const UNLOADING := &"unloading"
const BLOCKED := &"blocked"

var id: int
var source_id: int
var destination_id: int
var resource_id: StringName
var priority: int
var created_tick: int
var state: StringName = QUEUED
var worker_id: int = 0
var link_id: int = 0
var wait_reason: StringName


func _init(p_id: int, p_source_id: int, p_destination_id: int, p_resource_id: StringName, p_priority: int, p_created_tick: int) -> void:
    id = p_id
    source_id = p_source_id
    destination_id = p_destination_id
    resource_id = p_resource_id
    priority = p_priority
    created_tick = p_created_tick
