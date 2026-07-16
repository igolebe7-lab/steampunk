class_name SimulationController
extends Node

signal tick_completed(state: SimulationState)
signal interpolation_changed(alpha: float)
signal commands_flushed(state: SimulationState)
signal pause_changed(paused: bool)
signal speed_changed(multiplier: int)

const MAX_CATCH_UP_TICKS := 8
const PAUSED_MAX_FPS := 10

var tick_duration := 1.0 / float(SimulationRunner.DEFAULT_TICKS_PER_SECOND)

var _runner: SimulationRunner
var _accumulator := 0.0
var _paused := false
var _speed_multiplier := 1
var _running_max_fps := -1


func configure(runner: SimulationRunner) -> void:
    _runner = runner
    _accumulator = 0.0
    interpolation_changed.emit(0.0)


func set_paused(value: bool) -> void:
    if value == _paused:
        return
    if value and not _paused:
        _running_max_fps = Engine.max_fps
        Engine.max_fps = PAUSED_MAX_FPS
    elif not value and _paused and _running_max_fps >= 0:
        Engine.max_fps = _running_max_fps
    _paused = value
    OS.low_processor_usage_mode = value
    pause_changed.emit(value)


func is_paused() -> bool:
    return _paused


func set_speed_multiplier(value: int) -> bool:
    if not value in [1, 2, 4]:
        return false
    if value == _speed_multiplier:
        return true
    _speed_multiplier = value
    speed_changed.emit(value)
    return true


func get_speed_multiplier() -> int:
    return _speed_multiplier


func flush_commands() -> String:
    if _runner == null:
        return ""
    var result := _runner.flush_commands()
    commands_flushed.emit(_runner.state)
    return result


func advance_frame(delta: float) -> void:
    if _runner == null or delta <= 0.0:
        return
    if _paused:
        return
    _accumulator += delta * float(_speed_multiplier)
    var completed := 0
    while _accumulator >= tick_duration and completed < MAX_CATCH_UP_TICKS:
        _accumulator -= tick_duration
        _runner.step()
        tick_completed.emit(_runner.state)
        completed += 1
    if completed == MAX_CATCH_UP_TICKS and _accumulator >= tick_duration:
        _accumulator = minf(_accumulator, tick_duration)
    interpolation_changed.emit(get_interpolation_alpha())


func get_interpolation_alpha() -> float:
    return clampf(_accumulator / tick_duration, 0.0, 1.0)


func _process(delta: float) -> void:
    advance_frame(delta)
