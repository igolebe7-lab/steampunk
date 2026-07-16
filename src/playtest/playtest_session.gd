class_name PlaytestSession
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_MAX_ENTRIES := 4096

var id: String
var build_revision: String
var started_unix_ms: int
var max_entries: int
var entries: Array[PlaytestEntry] = []
var dropped_entries: int = 0
var outcome: StringName = &""
var ended_elapsed_ms: int = 0
var ended_tick: int = 0

var _next_sequence: int = 1


func _init(
    p_id: String,
    p_build_revision: String,
    p_started_unix_ms: int,
    p_max_entries: int = DEFAULT_MAX_ENTRIES
) -> void:
    id = p_id
    build_revision = p_build_revision
    started_unix_ms = p_started_unix_ms
    max_entries = maxi(p_max_entries, 1)


func append(
    elapsed_ms: int,
    tick: int,
    category: StringName,
    code: StringName,
    payload: Dictionary = {}
) -> PlaytestEntry:
    if is_finished() or entries.size() >= max_entries:
        dropped_entries += 1
        return null
    var entry := PlaytestEntry.new(
        _next_sequence,
        elapsed_ms,
        tick,
        category,
        code,
        payload
    )
    _next_sequence += 1
    entries.append(entry)
    return entry


func finish(p_outcome: StringName, elapsed_ms: int, tick: int) -> void:
    if is_finished():
        return
    outcome = p_outcome
    ended_elapsed_ms = maxi(elapsed_ms, 0)
    ended_tick = maxi(tick, 0)


func is_finished() -> bool:
    return not outcome.is_empty()


func to_dictionary() -> Dictionary:
    var encoded_entries: Array = []
    for entry: PlaytestEntry in entries:
        encoded_entries.append(entry.to_dictionary())
    return {
        "schema_version": SCHEMA_VERSION,
        "id": id,
        "build_revision": build_revision,
        "started_unix_ms": started_unix_ms,
        "max_entries": max_entries,
        "dropped_entries": dropped_entries,
        "outcome": String(outcome),
        "ended_elapsed_ms": ended_elapsed_ms,
        "ended_tick": ended_tick,
        "entries": encoded_entries,
    }


static func from_dictionary(data: Dictionary) -> PlaytestSession:
    if data.get("schema_version", 0) as int != SCHEMA_VERSION:
        return null
    var session := PlaytestSession.new(
        data.get("id", "") as String,
        data.get("build_revision", "") as String,
        data.get("started_unix_ms", 0) as int,
        data.get("max_entries", DEFAULT_MAX_ENTRIES) as int
    )
    var greatest_sequence := 0
    for value: Variant in data.get("entries", []) as Array:
        if not value is Dictionary:
            continue
        var entry := PlaytestEntry.from_dictionary(value as Dictionary)
        session.entries.append(entry)
        greatest_sequence = maxi(greatest_sequence, entry.sequence)
    session._next_sequence = greatest_sequence + 1
    session.dropped_entries = data.get("dropped_entries", 0) as int
    session.outcome = StringName(data.get("outcome", "") as String)
    session.ended_elapsed_ms = data.get("ended_elapsed_ms", 0) as int
    session.ended_tick = data.get("ended_tick", 0) as int
    return session
