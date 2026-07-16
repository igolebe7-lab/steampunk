class_name PlaytestLaunchOptions
extends RefCounted

var enabled: bool = false
var session_id: String = ""
var build_revision: String = ""
var error_code: StringName = &""


static func parse(
    args: PackedStringArray,
    fallback_build: String
) -> PlaytestLaunchOptions:
    var options := PlaytestLaunchOptions.new()
    options.build_revision = fallback_build
    for argument: String in args:
        if argument.begins_with("--playtest-session="):
            options.enabled = true
            options.session_id = argument.trim_prefix("--playtest-session=")
        elif argument.begins_with("--playtest-build="):
            var value := argument.trim_prefix("--playtest-build=")
            if not value.is_empty():
                options.build_revision = value
    if options.enabled and not _is_safe_session_id(options.session_id):
        options.error_code = &"invalid_session_id"
    return options


static func _is_safe_session_id(value: String) -> bool:
    if value.is_empty() or value.length() > 32:
        return false
    for index in value.length():
        var character := value.substr(index, 1)
        if (
            (character >= "a" and character <= "z")
            or (character >= "A" and character <= "Z")
            or (character >= "0" and character <= "9")
            or character in ["_", "-"]
        ):
            continue
        return false
    return true
