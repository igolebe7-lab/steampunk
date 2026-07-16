class_name PlaytestStorage
extends RefCounted

const MAX_JSON_BYTES := 1_048_576

var root_path: String
var _next_checkpoint_slot: int = 0


func _init(p_root_path: String = "user://playtests") -> void:
    root_path = p_root_path.trim_suffix("/")


func global_root_path() -> String:
    return ProjectSettings.globalize_path(root_path)


func write_checkpoint(session: PlaytestSession, json_text: String) -> Dictionary:
    var validation := _validate_write(session, json_text)
    if not validation.is_empty():
        return validation
    var prepared := _prepare_root()
    if not prepared.is_empty():
        return prepared
    var slot := "a" if _next_checkpoint_slot == 0 else "b"
    var path := root_path.path_join("%s.checkpoint-%s.json" % [session.id, slot])
    var result := _write_text(path, json_text)
    if result.get("ok", false) as bool:
        _next_checkpoint_slot = 1 - _next_checkpoint_slot
        result["path"] = path
    return result


func write_final(
    session: PlaytestSession,
    json_text: String,
    markdown_text: String
) -> Dictionary:
    var validation := _validate_write(session, json_text)
    if not validation.is_empty():
        return validation
    var prepared := _prepare_root()
    if not prepared.is_empty():
        return prepared
    var json_path := root_path.path_join("%s.json" % session.id)
    var markdown_path := root_path.path_join("%s-report.ru.md" % session.id)
    if FileAccess.file_exists(json_path) or FileAccess.file_exists(markdown_path):
        return {"ok": false, "error": "result_exists"}
    var json_temp := "%s.tmp" % json_path
    var markdown_temp := "%s.tmp" % markdown_path
    _remove_if_exists(json_temp)
    _remove_if_exists(markdown_temp)
    var json_result := _write_text(json_temp, json_text)
    if not (json_result.get("ok", false) as bool):
        return json_result
    var markdown_result := _write_text(markdown_temp, markdown_text)
    if not (markdown_result.get("ok", false) as bool):
        _remove_if_exists(json_temp)
        return markdown_result
    var json_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(json_temp),
        ProjectSettings.globalize_path(json_path)
    )
    if json_error != OK:
        _remove_if_exists(json_temp)
        _remove_if_exists(markdown_temp)
        return {"ok": false, "error": "storage_write", "error_code": json_error}
    var markdown_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(markdown_temp),
        ProjectSettings.globalize_path(markdown_path)
    )
    if markdown_error != OK:
        _remove_if_exists(json_path)
        _remove_if_exists(markdown_temp)
        return {"ok": false, "error": "storage_write", "error_code": markdown_error}
    return {
        "ok": true,
        "error": "",
        "json_path": json_path,
        "markdown_path": markdown_path,
    }


func load_latest_checkpoint(session_id: String) -> Dictionary:
    if not _is_safe_id(session_id):
        return {"ok": false, "error": "invalid_session_id"}
    var selected: Dictionary = {}
    var selected_sequence := -1
    for slot: String in ["a", "b"]:
        var path := root_path.path_join("%s.checkpoint-%s.json" % [session_id, slot])
        if not FileAccess.file_exists(path):
            continue
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            continue
        var parser := JSON.new()
        if parser.parse(file.get_as_text()) != OK:
            continue
        var parsed: Variant = parser.data
        if not parsed is Dictionary:
            continue
        var data := parsed as Dictionary
        var session_data := data.get("session", {}) as Dictionary
        if session_data.get("id", "") != session_id:
            continue
        var sequence := _last_sequence(session_data)
        if sequence >= selected_sequence:
            selected_sequence = sequence
            selected = {"ok": true, "error": "", "path": path, "data": data}
    if selected.is_empty():
        return {"ok": false, "error": "checkpoint_missing"}
    return selected


func clear_checkpoints(session_id: String) -> void:
    if not _is_safe_id(session_id):
        return
    for slot: String in ["a", "b"]:
        _remove_if_exists(root_path.path_join(
            "%s.checkpoint-%s.json" % [session_id, slot]
        ))


func _validate_write(session: PlaytestSession, json_text: String) -> Dictionary:
    if session == null or not _is_safe_id(session.id):
        return {"ok": false, "error": "invalid_session_id"}
    if json_text.to_utf8_buffer().size() > MAX_JSON_BYTES:
        return {"ok": false, "error": "report_too_large"}
    return {}


func _prepare_root() -> Dictionary:
    var error := DirAccess.make_dir_recursive_absolute(global_root_path())
    if error != OK:
        return {"ok": false, "error": "storage_write", "error_code": error}
    return {}


func _write_text(path: String, text: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {
            "ok": false,
            "error": "storage_write",
            "error_code": FileAccess.get_open_error(),
        }
    file.store_string(text)
    var error := file.get_error()
    file.close()
    if error != OK:
        return {"ok": false, "error": "storage_write", "error_code": error}
    return {"ok": true, "error": ""}


func _last_sequence(session_data: Dictionary) -> int:
    var entries := session_data.get("entries", []) as Array
    if entries.is_empty() or not entries[-1] is Dictionary:
        return 0
    return (entries[-1] as Dictionary).get("sequence", 0) as int


func _remove_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _is_safe_id(value: String) -> bool:
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
