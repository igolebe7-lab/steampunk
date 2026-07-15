class_name RecipeDef
extends Resource

@export var id: StringName
@export var input_resource_ids: Array[StringName] = []
@export var input_amounts: Array[int] = []
@export_range(1, 100000) var duration_ticks: int = 1
@export var result_code: StringName
@export var display_name_key: StringName
@export var description_key: StringName


func input_amount(resource_id: StringName) -> int:
    var index := input_resource_ids.find(resource_id)
    return 0 if index < 0 else input_amounts[index]
