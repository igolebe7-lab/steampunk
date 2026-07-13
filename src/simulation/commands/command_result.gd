class_name CommandResult
extends RefCounted

var accepted: bool
var code: StringName


func _init(p_accepted: bool, p_code: StringName) -> void:
    accepted = p_accepted
    code = p_code


static func success() -> CommandResult:
    return CommandResult.new(true, &"accepted")


static func rejected(p_code: StringName) -> CommandResult:
    return CommandResult.new(false, p_code)
