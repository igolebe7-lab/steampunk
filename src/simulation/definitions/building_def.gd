class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0, 100000) var inventory_capacity: int = 0
