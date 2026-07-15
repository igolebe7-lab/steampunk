class_name LogisticsLinkState
extends RefCounted

var id: int:
    get:
        return _id
var source_id: int:
    get:
        return _source_id
var destination_id: int:
    get:
        return _destination_id
var resource_id: StringName:
    get:
        return _resource_id
var is_automatic: bool
var quota: int
var priority: int
var dispatch_enabled: bool
var is_closing: bool
var waiting_ticks: int = 0

var _id: int
var _source_id: int
var _destination_id: int
var _resource_id: StringName


func _init(
    p_id: int,
    p_source_id: int,
    p_destination_id: int,
    p_resource_id: StringName,
    p_is_automatic: bool,
    p_quota: int,
    p_priority: int,
    p_dispatch_enabled: bool = true,
    p_is_closing: bool = false
) -> void:
    _id = p_id
    _source_id = p_source_id
    _destination_id = p_destination_id
    _resource_id = p_resource_id
    is_automatic = p_is_automatic
    quota = p_quota
    priority = p_priority
    dispatch_enabled = p_dispatch_enabled
    is_closing = p_is_closing
