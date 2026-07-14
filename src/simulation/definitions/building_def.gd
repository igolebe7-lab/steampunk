class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0, 100000) var inventory_capacity: int = 0
@export var source_resource_id: StringName
@export_range(0, 100000) var source_interval_ticks: int = 0
@export_range(0, 100000) var source_capacity: int = 0


func is_source() -> bool:
    return not source_resource_id.is_empty()
