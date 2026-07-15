class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0, 100000) var inventory_capacity: int = 0
@export var source_resource_id: StringName
@export_range(0, 100000) var source_interval_ticks: int = 0
@export_range(0, 100000) var source_capacity: int = 0
@export var role: StringName = LogisticsPortDef.ROLE_STORAGE
@export_range(1, 100) var max_level: int = 1
@export var outgoing_worker_slots_by_level: Array[int] = [0]
@export var logistics_ports: Array[LogisticsPortDef] = []
@export var allows_direct_delivery_to_main: bool = true


func is_source() -> bool:
    return not source_resource_id.is_empty()


func outgoing_worker_slots(level: int) -> int:
    if level < 1 or level > outgoing_worker_slots_by_level.size():
        return 0
    return outgoing_worker_slots_by_level[level - 1]
