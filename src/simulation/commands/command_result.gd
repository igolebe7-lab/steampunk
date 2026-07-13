class_name CommandResult
extends RefCounted

var accepted: bool
var code: StringName
var command_id: StringName


func _init(p_accepted: bool, p_code: StringName, p_command_id: StringName = &"") -> void:
    accepted = p_accepted
    code = p_code
    command_id = p_command_id


static func success(p_command_id: StringName = &"") -> CommandResult:
    return CommandResult.new(true, &"accepted", p_command_id)


static func rejected(p_code: StringName, p_command_id: StringName = &"") -> CommandResult:
    return CommandResult.new(false, p_code, p_command_id)
