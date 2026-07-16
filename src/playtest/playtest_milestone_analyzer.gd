class_name PlaytestMilestoneAnalyzer
extends RefCounted

const LOGISTICS_ACTIONS: Array[StringName] = [
    &"road_cell",
    &"depot_cell",
    &"link_complete",
    &"link_settings",
    &"dispatch_policy",
    &"remove_link",
    &"reset_link",
    &"demolish_depot",
    &"pipe_build",
    &"pipe_remove",
]
const INSPECTED_KINDS: Array[String] = [
    "worker",
    "building",
    "link",
    "utility_segment",
]
const IDLE_THRESHOLD_MS := 30_000
const IMPROVEMENT_RATIO := 1.25
const MIN_ABSOLUTE_GAIN := 0.5
const IMPROVEMENT_MIN_TICKS := 300
const IMPROVEMENT_MAX_TICKS := 600


func analyze(session: PlaytestSession) -> Dictionary:
    if session == null:
        return _empty_result()
    var result := _empty_result()
    var samples: Array[PlaytestEntry] = []
    var accepted_actions: Array[PlaytestEntry] = []
    var last_action_ms := 0
    var last_manual_water := 0
    var last_pipe_water := 0

    for entry: PlaytestEntry in session.entries:
        if entry.code == &"flow_sample":
            samples.append(entry)
            last_manual_water = entry.payload.get("manual_water", 0) as int
            last_pipe_water = entry.payload.get("pipe_water", 0) as int
        _capture_milestone(result["milestones"] as Dictionary, entry)
        _capture_layer_usage(result["layer_usage"] as Dictionary, entry)
        if entry.category == &"command":
            var accepted: bool = entry.payload.get("result", "") == "accepted"
            var count_key := "accepted" if accepted else "rejected"
            var counts := result["command_counts"] as Dictionary
            counts[count_key] = (counts.get(count_key, 0) as int) + 1
            if accepted and entry.code in LOGISTICS_ACTIONS:
                accepted_actions.append(entry)
        if entry.category in [&"ui", &"command"]:
            _append_idle_period(result["idle_periods"] as Array, last_action_ms, entry.elapsed_ms)
            last_action_ms = entry.elapsed_ms

    if session.is_finished():
        _append_idle_period(
            result["idle_periods"] as Array,
            last_action_ms,
            session.ended_elapsed_ms
        )
    result["water_path"] = _water_path(last_manual_water, last_pipe_water)
    var candidates := result["bottleneck_candidates"] as Array
    for action: PlaytestEntry in accepted_actions:
        var candidate := _bottleneck_candidate(action, samples)
        if candidate.is_empty():
            continue
        candidates.append(candidate)
        var milestones := result["milestones"] as Dictionary
        var first_improvement := milestones.get("first_flow_improvement_ms", -1) as int
        if first_improvement < 0:
            milestones["first_flow_improvement_ms"] = action.elapsed_ms
    return result


func _empty_result() -> Dictionary:
    return {
        "milestones": {
            "first_logistics_action_ms": -1,
            "first_inspector_ms": -1,
            "first_flow_improvement_ms": -1,
        },
        "idle_periods": [],
        "water_path": "none",
        "command_counts": {"accepted": 0, "rejected": 0},
        "layer_usage": {},
        "bottleneck_candidates": [],
    }


func _capture_milestone(milestones: Dictionary, entry: PlaytestEntry) -> void:
    var first_logistics := milestones.get("first_logistics_action_ms", -1) as int
    if (
        entry.category == &"command"
        and entry.code in LOGISTICS_ACTIONS
        and entry.payload.get("result", "") == "accepted"
        and first_logistics < 0
    ):
        milestones["first_logistics_action_ms"] = entry.elapsed_ms
    var first_inspector := milestones.get("first_inspector_ms", -1) as int
    if (
        entry.code == &"selection"
        and entry.payload.get("kind", "") in INSPECTED_KINDS
        and first_inspector < 0
    ):
        milestones["first_inspector_ms"] = entry.elapsed_ms
    if entry.code == &"scenario_phase_changed":
        var phase := entry.payload.get("phase", "") as String
        if not phase.is_empty():
            milestones["phase_%s_ms" % phase] = entry.elapsed_ms


func _capture_layer_usage(layer_usage: Dictionary, entry: PlaytestEntry) -> void:
    if entry.code != &"layer_visibility" or not (entry.payload.get("visible", false) as bool):
        return
    var layer := entry.payload.get("layer", "") as String
    if layer.is_empty():
        return
    layer_usage[layer] = (layer_usage.get(layer, 0) as int) + 1


func _append_idle_period(periods: Array, start_ms: int, end_ms: int) -> void:
    var duration := end_ms - start_ms
    if duration <= IDLE_THRESHOLD_MS:
        return
    periods.append({
        "start_ms": start_ms,
        "end_ms": end_ms,
        "duration_ms": duration,
    })


func _water_path(manual_water: int, pipe_water: int) -> String:
    if manual_water > 0 and pipe_water > 0:
        return "mixed"
    if pipe_water > 0:
        return "pipe"
    if manual_water > 0:
        return "manual"
    return "none"


func _bottleneck_candidate(
    action: PlaytestEntry,
    samples: Array[PlaytestEntry]
) -> Dictionary:
    var before: PlaytestEntry
    var after: PlaytestEntry
    for sample: PlaytestEntry in samples:
        if sample.tick <= action.tick:
            before = sample
            continue
        var delta := sample.tick - action.tick
        if delta < IMPROVEMENT_MIN_TICKS:
            continue
        if delta > IMPROVEMENT_MAX_TICKS:
            break
        after = sample
        break
    if before == null or after == null:
        return {}
    var diagnostic_before := before.payload.get("diagnostic_code", "") as String
    var diagnostic_after := after.payload.get("diagnostic_code", "") as String
    if diagnostic_before.is_empty() or diagnostic_before == diagnostic_after:
        return {}
    var link_id := action.payload.get("link_id", 0) as int
    var throughput_before := _throughput(before.payload, link_id)
    var throughput_after := _throughput(after.payload, link_id)
    if (
        throughput_after < throughput_before * IMPROVEMENT_RATIO
        or throughput_after - throughput_before < MIN_ABSOLUTE_GAIN
    ):
        return {}
    return {
        "action_code": String(action.code),
        "elapsed_ms": action.elapsed_ms,
        "tick": action.tick,
        "diagnostic_before": diagnostic_before,
        "diagnostic_after": diagnostic_after,
        "throughput_before": throughput_before,
        "throughput_after": throughput_after,
        "link_id": link_id,
        "confirmed": false,
    }


func _throughput(payload: Dictionary, link_id: int) -> float:
    if link_id > 0:
        var links := payload.get("link_throughput_per_minute", {}) as Dictionary
        return float(links.get(str(link_id), links.get(link_id, 0.0)))
    var total := 0.0
    var main := payload.get("main_throughput_per_minute", {}) as Dictionary
    for value: Variant in main.values():
        total += float(value)
    return total
