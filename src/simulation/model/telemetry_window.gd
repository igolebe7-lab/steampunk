class_name TelemetryWindow
extends RefCounted

const WINDOW_TICKS := 600
const WARMUP_TICKS := 100
const TICKS_PER_MINUTE := 600

var total_samples: int = 0
var cumulative_main_deliveries: Dictionary = {}
var cumulative_link_deliveries: Dictionary = {}
var cumulative_completed_jobs: int = 0
var cumulative_manual_water_delivered: int = 0
var cumulative_pipe_water_delivered: int = 0

var _samples: Array[Dictionary] = []
var _fingerprints: PackedStringArray = []
var _start: int = 0
var _main_deliveries: Dictionary = {}
var _link_deliveries: Dictionary = {}
var _job_latency_total: int = 0
var _completed_jobs: int = 0
var _moving_worker_ticks: int = 0
var _waiting_worker_ticks: int = 0
var _queue_depth_ticks: int = 0
var _link_load_ticks: Dictionary = {}
var _cell_load_ticks: Dictionary = {}
var _cell_conflicts: Dictionary = {}
var _loss_ticks: Dictionary = {}
var _loss_link_ticks: Dictionary = {}
var _loss_cell_ticks: Dictionary = {}


func append_sample(sample: Dictionary) -> void:
    var stored := sample.duplicate(true)
    var fingerprint := _sample_fingerprint(stored)
    if _samples.size() == WINDOW_TICKS:
        _accumulate(_samples[_start], -1, false)
        _samples[_start] = stored
        _fingerprints[_start] = fingerprint
        _start = (_start + 1) % WINDOW_TICKS
    else:
        _samples.append(stored)
        _fingerprints.append(fingerprint)
    total_samples += 1
    _accumulate(stored, 1, true)


func size() -> int:
    return _samples.size()


func is_warm() -> bool:
    return total_samples >= WARMUP_TICKS


func oldest_tick() -> int:
    if _samples.is_empty():
        return 0
    return _samples[_start].get(&"tick", 0) as int


func latest_tick() -> int:
    if _samples.is_empty():
        return 0
    var index := (_start + _samples.size() - 1) % _samples.size()
    return _samples[index].get(&"tick", 0) as int


func ordered_samples() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for offset in _samples.size():
        result.append(_samples[(_start + offset) % _samples.size()])
    return result


func ordered_fingerprints() -> PackedStringArray:
    var result: PackedStringArray = []
    for offset in _fingerprints.size():
        result.append(_fingerprints[(_start + offset) % _fingerprints.size()])
    return result


func main_throughput_per_minute(resource_id: StringName) -> float:
    return _per_minute(_main_deliveries.get(resource_id, 0) as int)


func link_throughput_per_minute(link_id: int) -> float:
    return _per_minute(_link_deliveries.get(link_id, 0) as int)


func average_job_latency_ticks() -> float:
    return _average(_job_latency_total, _completed_jobs)


func average_moving_workers() -> float:
    return _average(_moving_worker_ticks, size())


func average_waiting_workers() -> float:
    return _average(_waiting_worker_ticks, size())


func average_queue_depth() -> float:
    return _average(_queue_depth_ticks, size())


func average_link_load(link_id: int) -> float:
    return _average(_link_load_ticks.get(link_id, 0) as int, size())


func average_cell_load(cell_key: StringName) -> float:
    return _average(_cell_load_ticks.get(cell_key, 0) as int, size())


func cell_conflict_count(cell_key: StringName) -> int:
    return _cell_conflicts.get(cell_key, 0) as int


func loss_ticks(code: StringName) -> int:
    return _loss_ticks.get(code, 0) as int


func biggest_loss_link(code: StringName) -> int:
    return _biggest_int_key(_loss_link_ticks.get(code, {}) as Dictionary)


func biggest_loss_cell(code: StringName) -> StringName:
    return _biggest_name_key(_loss_cell_ticks.get(code, {}) as Dictionary)


func _accumulate(sample: Dictionary, direction: int, include_cumulative: bool) -> void:
    var main := sample.get(&"main_deliveries", {}) as Dictionary
    var links := sample.get(&"link_deliveries", {}) as Dictionary
    _merge_counts(_main_deliveries, main, direction)
    _merge_counts(_link_deliveries, links, direction)
    _job_latency_total += (sample.get(&"job_latency_total", 0) as int) * direction
    var completed := sample.get(&"completed_jobs", 0) as int
    _completed_jobs += completed * direction
    _moving_worker_ticks += (sample.get(&"moving_workers", 0) as int) * direction
    _waiting_worker_ticks += (sample.get(&"waiting_workers", 0) as int) * direction
    _queue_depth_ticks += (sample.get(&"queue_depth", 0) as int) * direction
    _merge_counts(_link_load_ticks, sample.get(&"link_load", {}) as Dictionary, direction)
    _merge_counts(_cell_load_ticks, sample.get(&"cell_load", {}) as Dictionary, direction)
    _merge_counts(_cell_conflicts, sample.get(&"cell_conflicts", {}) as Dictionary, direction)
    var losses := sample.get(&"losses", {}) as Dictionary
    _merge_counts(_loss_ticks, losses, direction)
    _accumulate_loss_attribution(sample, losses, direction)
    if include_cumulative:
        _merge_counts(cumulative_main_deliveries, main, 1)
        _merge_counts(cumulative_link_deliveries, links, 1)
        cumulative_completed_jobs += completed


func _accumulate_loss_attribution(sample: Dictionary, losses: Dictionary, direction: int) -> void:
    var loss_links := sample.get(&"loss_links", {}) as Dictionary
    var loss_cells := sample.get(&"loss_cells", {}) as Dictionary
    for code_value: Variant in losses.keys():
        var code := code_value as StringName
        var amount := losses[code] as int
        if loss_links.has(code):
            _merge_nested_count(_loss_link_ticks, code, loss_links[code] as int, amount * direction)
        if loss_cells.has(code):
            _merge_nested_count(_loss_cell_ticks, code, loss_cells[code] as StringName, amount * direction)


func _merge_counts(target: Dictionary, values: Dictionary, direction: int) -> void:
    for key: Variant in values.keys():
        var updated := (target.get(key, 0) as int) + (values[key] as int) * direction
        if updated == 0:
            target.erase(key)
        else:
            target[key] = updated


func _merge_nested_count(target: Dictionary, group: Variant, key: Variant, amount: int) -> void:
    var values := target.get(group, {}) as Dictionary
    var updated := (values.get(key, 0) as int) + amount
    if updated == 0:
        values.erase(key)
    else:
        values[key] = updated
    if values.is_empty():
        target.erase(group)
    else:
        target[group] = values


func _per_minute(amount: int) -> float:
    if size() == 0:
        return 0.0
    return float(amount * TICKS_PER_MINUTE) / float(size())


func _average(total: int, count: int) -> float:
    return 0.0 if count == 0 else float(total) / float(count)


func _biggest_int_key(values: Dictionary) -> int:
    var selected := 0
    var selected_value := -1
    for key_value: Variant in values.keys():
        var key := key_value as int
        var amount := values[key] as int
        if amount > selected_value or (amount == selected_value and key < selected):
            selected = key
            selected_value = amount
    return selected


func _biggest_name_key(values: Dictionary) -> StringName:
    var selected := &""
    var selected_value := -1
    for key_value: Variant in values.keys():
        var key := key_value as StringName
        var amount := values[key] as int
        if amount > selected_value or (amount == selected_value and str(key) < str(selected)):
            selected = key
            selected_value = amount
    return selected


func _sample_fingerprint(sample: Dictionary) -> String:
    return "%d|main=%s|links=%s|latency=%d|jobs=%d|moving=%d|waiting=%d|queue=%d|link_load=%s|cell_load=%s|conflicts=%s|losses=%s|loss_links=%s|loss_cells=%s" % [
        sample.get(&"tick", 0) as int,
        _encode_counts(sample.get(&"main_deliveries", {}) as Dictionary),
        _encode_counts(sample.get(&"link_deliveries", {}) as Dictionary),
        sample.get(&"job_latency_total", 0) as int,
        sample.get(&"completed_jobs", 0) as int,
        sample.get(&"moving_workers", 0) as int,
        sample.get(&"waiting_workers", 0) as int,
        sample.get(&"queue_depth", 0) as int,
        _encode_counts(sample.get(&"link_load", {}) as Dictionary),
        _encode_counts(sample.get(&"cell_load", {}) as Dictionary),
        _encode_counts(sample.get(&"cell_conflicts", {}) as Dictionary),
        _encode_counts(sample.get(&"losses", {}) as Dictionary),
        _encode_values(sample.get(&"loss_links", {}) as Dictionary),
        _encode_values(sample.get(&"loss_cells", {}) as Dictionary),
    ]


func _encode_counts(values: Dictionary) -> String:
    var keys := values.keys()
    keys.sort_custom(_variant_key_precedes)
    var parts: PackedStringArray = []
    for key: Variant in keys:
        parts.append("%s=%d" % [_key_token(key), values[key] as int])
    return ",".join(parts)


func _encode_values(values: Dictionary) -> String:
    var keys := values.keys()
    keys.sort_custom(_variant_key_precedes)
    var parts: PackedStringArray = []
    for key: Variant in keys:
        parts.append("%s=%s" % [_key_token(key), _key_token(values[key])])
    return ",".join(parts)


func _variant_key_precedes(left: Variant, right: Variant) -> bool:
    return _key_token(left) < _key_token(right)


func _key_token(value: Variant) -> String:
    if value is int:
        return "i:%d" % (value as int)
    return "n:%s" % String(value).uri_encode()
