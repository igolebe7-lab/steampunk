class_name DeliveryFlowState
extends RefCounted

var id: int
var source_id: int
var destination_id: int
var resource_id: StringName
var priority: int


func _init(p_id: int, p_source_id: int, p_destination_id: int, p_resource_id: StringName, p_priority: int) -> void:
    id = p_id
    source_id = p_source_id
    destination_id = p_destination_id
    resource_id = p_resource_id
    priority = p_priority
