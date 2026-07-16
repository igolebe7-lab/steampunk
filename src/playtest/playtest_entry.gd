class_name PlaytestEntry
extends RefCounted

var sequence: int
var elapsed_ms: int
var tick: int
var category: StringName
var code: StringName
var payload: Dictionary


func _init(
    p_sequence: int,
    p_elapsed_ms: int,
    p_tick: int,
    p_category: StringName,
    p_code: StringName,
    p_payload: Dictionary = {}
) -> void:
    sequence = p_sequence
    elapsed_ms = maxi(p_elapsed_ms, 0)
    tick = maxi(p_tick, 0)
    category = p_category
    code = p_code
    payload = PlaytestValueEncoder.encode(p_payload) as Dictionary


func to_dictionary() -> Dictionary:
    return {
        "sequence": sequence,
        "elapsed_ms": elapsed_ms,
        "tick": tick,
        "category": String(category),
        "code": String(code),
        "payload": payload.duplicate(true),
    }


static func from_dictionary(data: Dictionary) -> PlaytestEntry:
    return PlaytestEntry.new(
        data.get("sequence", 0) as int,
        data.get("elapsed_ms", 0) as int,
        data.get("tick", 0) as int,
        StringName(data.get("category", "") as String),
        StringName(data.get("code", "") as String),
        data.get("payload", {}) as Dictionary
    )
