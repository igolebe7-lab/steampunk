class_name CommandResult
extends RefCounted

var accepted: bool
var code: StringName
var command_id: StringName
var parameters: Dictionary


func _init(
    p_accepted: bool,
    p_code: StringName,
    p_command_id: StringName = &"",
    p_parameters: Dictionary = {}
) -> void:
    accepted = p_accepted
    code = p_code
    command_id = p_command_id
    parameters = p_parameters.duplicate(true)


static func success(p_command_id: StringName = &"", p_parameters: Dictionary = {}) -> CommandResult:
    return CommandResult.new(true, &"accepted", p_command_id, p_parameters)


static func rejected(
    p_code: StringName,
    p_command_id: StringName = &"",
    p_parameters: Dictionary = {}
) -> CommandResult:
    return CommandResult.new(false, p_code, p_command_id, p_parameters)
