class_name SimulationRunner
extends RefCounted

const DEFAULT_TICKS_PER_SECOND := 10

var state: SimulationState

var _queue := CommandQueue.new()
var _command_system := CommandSystem.new()
var _logistics_pipeline := LogisticsPipeline.new()
var _invariant_checker := InvariantChecker.new()
var _hasher := StateHasher.new()


func _init(p_state: SimulationState) -> void:
    assert(p_state != null, "SimulationRunner требует загруженное состояние")
    state = p_state


func enqueue(command: SimulationCommand) -> CommandResult:
    return _queue.enqueue(command, state.tick)


func step() -> String:
    state.last_events.clear()
    state.events.clear()
    var target_tick := state.tick + 1
    for command in _queue.take_for_tick(target_tick):
        var result := _command_system.apply(state, command)
        state.last_events.append(result.code)

    _logistics_pipeline.run(state, target_tick)
    var invariant_errors := _invariant_checker.check(state)
    if not invariant_errors.is_empty():
        var message := "Нарушены инварианты симуляции: %s" % [invariant_errors]
        push_error(message)
        assert(false, message)
        return ""
    state.tick = target_tick
    return _hasher.hash_state(state)


func run_ticks(count: int) -> Array[String]:
    assert(count >= 0, "Количество тиков не может быть отрицательным")
    var hashes: Array[String] = []
    for _index in count:
        hashes.append(step())
    return hashes
