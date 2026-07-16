class_name PlaytestRecorder
extends RefCounted

signal checkpoint_requested(session: PlaytestSession)
signal finished(session: PlaytestSession)

const CAPTURED_EVENTS: Array[StringName] = [
    &"cargo_delivered",
    &"pipe_built",
    &"pipe_removed",
    &"pipe_water_delivered",
    &"production_started",
    &"production_completed",
    &"boiler_cooled",
    &"hammer_struck",
]
const SAMPLE_INTERVAL_TICKS := 100
const CHECKPOINT_INTERVAL_MS := 60_000

var session: PlaytestSession

var _clock_ms: Callable
var _started_clock_ms: int = 0
var _last_checkpoint_ms: int = 0
var _last_sample_tick: int = -SAMPLE_INTERVAL_TICKS
var _last_phase: StringName = &""
var _last_diagnostic_code: StringName = &""
var _diagnostic_initialized: bool = false
var _last_event_batch_key: String = ""


func configure(p_session: PlaytestSession, p_clock_ms: Callable = Callable()) -> void:
    assert(p_session != null, "PlaytestRecorder требует сессию")
    session = p_session
    _clock_ms = p_clock_ms
    _started_clock_ms = _now_ms()
    _last_checkpoint_ms = 0


func record_action(
    tick: int,
    category: StringName,
    code: StringName,
    payload: Dictionary = {}
) -> void:
    _append(tick, category, code, payload)


func record_command(
    state: SimulationState,
    intent_code: StringName,
    result_code: StringName,
    payload: Dictionary = {}
) -> void:
    if state == null:
        return
    var command_payload := payload.duplicate(true)
    command_payload[&"result"] = result_code
    _append(state.tick, &"command", intent_code, command_payload)


func capture_state(state: SimulationState) -> void:
    if state == null or session == null or session.is_finished():
        return
    var phase_changed := _capture_phase(state)
    _capture_diagnostic(state)
    _capture_events(state)
    _capture_flow_sample(state)
    var elapsed := _elapsed_ms()
    if phase_changed or elapsed - _last_checkpoint_ms >= CHECKPOINT_INTERVAL_MS:
        _last_checkpoint_ms = elapsed
        checkpoint_requested.emit(session)


func finish(p_outcome: StringName, state: SimulationState) -> void:
    if session == null or session.is_finished():
        return
    session.finish(p_outcome, _elapsed_ms(), 0 if state == null else state.tick)
    finished.emit(session)


func _capture_phase(state: SimulationState) -> bool:
    var phase := state.scenario_progress.phase
    if phase == _last_phase:
        return false
    _last_phase = phase
    _append(state.tick, &"state", &"scenario_phase_changed", {&"phase": phase})
    return true


func _capture_diagnostic(state: SimulationState) -> void:
    var report := state.diagnostic_report
    var code := &"" if report == null else report.code
    if _diagnostic_initialized and code == _last_diagnostic_code:
        return
    _diagnostic_initialized = true
    _last_diagnostic_code = code
    _append(state.tick, &"state", &"diagnostic_changed", {
        &"code": code,
        &"loss_ticks": 0 if report == null else report.loss_ticks,
        &"link_id": 0 if report == null else report.link_id,
        &"cell_key": &"" if report == null else report.cell_key,
    })


func _capture_events(state: SimulationState) -> void:
    var batch_key := _event_batch_key(state)
    if batch_key == _last_event_batch_key:
        return
    _last_event_batch_key = batch_key
    for event: SimulationEvent in state.events:
        if event.code not in CAPTURED_EVENTS:
            continue
        _append(state.tick, &"simulation", event.code, {
            &"entity_id": event.entity_id,
            &"job_id": event.job_id,
            &"resource_id": event.resource_id,
            &"link_id": event.link_id,
            &"destination_id": event.destination_id,
            &"metric_value": event.metric_value,
            &"cell_key": event.cell_key,
            &"reason": event.reason,
        })


func _capture_flow_sample(state: SimulationState) -> void:
    if state.tick - _last_sample_tick < SAMPLE_INTERVAL_TICKS:
        return
    _last_sample_tick = state.tick
    _append(state.tick, &"state", &"flow_sample", {
        &"main_throughput_per_minute": state.telemetry.get(
            &"main_throughput_per_minute", {}
        ),
        &"link_throughput_per_minute": state.telemetry.get(
            &"link_throughput_per_minute", {}
        ),
        &"completed_jobs": state.telemetry_window.cumulative_completed_jobs,
        &"manual_water": state.utility_network.manual_water_delivered,
        &"pipe_water": state.utility_network.pipe_water_delivered,
        &"diagnostic_code": state.diagnostic_report.code,
    })


func _event_batch_key(state: SimulationState) -> String:
    var parts: PackedStringArray = [str(state.tick), str(state.revision)]
    for event: SimulationEvent in state.events:
        parts.append("%s:%d:%d:%d" % [event.code, event.entity_id, event.job_id, event.link_id])
    return "|".join(parts)


func _append(
    tick: int,
    category: StringName,
    code: StringName,
    payload: Dictionary
) -> void:
    if session == null or session.is_finished():
        return
    session.append(_elapsed_ms(), tick, category, code, payload)


func _elapsed_ms() -> int:
    return maxi(_now_ms() - _started_clock_ms, 0)


func _now_ms() -> int:
    if _clock_ms.is_valid():
        return _clock_ms.call() as int
    return Time.get_ticks_msec()
