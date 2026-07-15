class_name SimulationController
extends Node

signal tick_completed(state: SimulationState)
signal interpolation_changed(alpha: float)
signal commands_flushed(state: SimulationState)

const MAX_CATCH_UP_TICKS := 8

var tick_duration := 1.0 / float(SimulationRunner.DEFAULT_TICKS_PER_SECOND)

var _runner: SimulationRunner
var _accumulator := 0.0
var _paused := false
var _speed_multiplier := 1


func configure(runner: SimulationRunner) -> void:
    _runner = runner
    _accumulator = 0.0
    interpolation_changed.emit(0.0)


func set_paused(value: bool) -> void:
    _paused = value


func is_paused() -> bool:
    return _paused


func set_speed_multiplier(value: int) -> bool:
    if not value in [1, 2, 4]:
        return false
    _speed_multiplier = value
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
        interpolation_changed.emit(get_interpolation_alpha())
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
