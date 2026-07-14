class_name BuildingState
extends RefCounted

var id: int:
    get:
        return _id
var definition_id: StringName:
    get:
        return _definition_id
var coord: HexCoord:
    get:
        return _coord
var priority: int
var inventory_capacity: int = 0
var inventories: Dictionary = {}
var outgoing_reserved: Dictionary = {}
var incoming_reserved: Dictionary = {}
var source_progress_ticks: int = 0

var _id: int
var _definition_id: StringName
var _coord: HexCoord


func _init(
    p_id: int,
    p_definition_id: StringName,
    p_coord: HexCoord,
    p_priority: int
) -> void:
    _id = p_id
    _definition_id = p_definition_id
    _coord = p_coord
    priority = p_priority


func get_amount(resource_id: StringName) -> int:
    return inventories.get(resource_id, 0) as int


func add_amount(resource_id: StringName, amount: int) -> bool:
    if amount < 0 or get_amount(resource_id) + amount > inventory_capacity:
        return false
    inventories[resource_id] = get_amount(resource_id) + amount
    return true


func get_outgoing_reserved(resource_id: StringName) -> int:
    return outgoing_reserved.get(resource_id, 0) as int


func get_incoming_reserved(resource_id: StringName) -> int:
    return incoming_reserved.get(resource_id, 0) as int


func reserve_outgoing(resource_id: StringName, amount: int) -> bool:
    if amount <= 0 or get_amount(resource_id) - get_outgoing_reserved(resource_id) < amount:
        return false
    outgoing_reserved[resource_id] = get_outgoing_reserved(resource_id) + amount
    return true


func reserve_incoming(resource_id: StringName, amount: int) -> bool:
    if amount <= 0 or free_capacity() < amount:
        return false
    incoming_reserved[resource_id] = get_incoming_reserved(resource_id) + amount
    return true


func release_outgoing(resource_id: StringName, amount: int) -> bool:
    if amount <= 0 or get_outgoing_reserved(resource_id) < amount:
        return false
    outgoing_reserved[resource_id] = get_outgoing_reserved(resource_id) - amount
    return true


func release_incoming(resource_id: StringName, amount: int) -> bool:
    if amount <= 0 or get_incoming_reserved(resource_id) < amount:
        return false
    incoming_reserved[resource_id] = get_incoming_reserved(resource_id) - amount
    return true


func remove_amount(resource_id: StringName, amount: int) -> bool:
    if amount <= 0 or get_amount(resource_id) < amount:
        return false
    inventories[resource_id] = get_amount(resource_id) - amount
    return true


func free_capacity() -> int:
    var used := 0
    for amount in inventories.values():
        used += amount as int
    for amount in incoming_reserved.values():
        used += amount as int
    return maxi(inventory_capacity - used, 0)
