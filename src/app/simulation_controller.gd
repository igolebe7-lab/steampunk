class_name SimulationController
extends Node

signal tick_completed(state: SimulationState)
signal interpolation_changed(alpha: float)

const MAX_CATCH_UP_TICKS := 8

var tick_duration := 1.0 / float(SimulationRunner.DEFAULT_TICKS_PER_SECOND)

var _runner: SimulationRunner
var _accumulator := 0.0


func configure(runner: SimulationRunner) -> void:
    _runner = runner
    _accumulator = 0.0
    interpolation_changed.emit(0.0)


func advance_frame(delta: float) -> void:
    if _runner == null or delta <= 0.0:
        return
    _accumulator += delta
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
