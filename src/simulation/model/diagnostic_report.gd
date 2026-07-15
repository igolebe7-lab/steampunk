class_name DiagnosticReport
extends RefCounted

const SUPPORTED_CODES: Array[StringName] = [
    &"no_destination",
    &"destination_full",
    &"source_full",
    &"worker_shortage",
    &"route_conflict",
    &"relay_backlog",
    &"no_path",
]

var code: StringName = &""
var loss_ticks: int = 0
var link_id: int = 0
var cell_key: StringName = &""


func _init(
    p_code: StringName = &"",
    p_loss_ticks: int = 0,
    p_link_id: int = 0,
    p_cell_key: StringName = &""
) -> void:
    code = p_code
    loss_ticks = p_loss_ticks
    link_id = p_link_id
    cell_key = p_cell_key


static func is_supported_code(value: StringName) -> bool:
    return value in SUPPORTED_CODES
