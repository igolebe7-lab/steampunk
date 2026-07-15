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
    _begin_transaction()
    var target_tick := state.tick + 1
    _apply_commands_for_tick(target_tick)
    _logistics_pipeline.run(state, target_tick)
    state.tick = target_tick
    return _validate_and_hash()


func flush_commands() -> String:
    _begin_transaction()
    _apply_commands_for_tick(state.tick + 1)
    return _validate_and_hash()


func _begin_transaction() -> void:
    state.last_events.clear()
    state.events.clear()


func _apply_commands_for_tick(target_tick: int) -> void:
    var commands := _queue.take_for_tick(target_tick)
    if commands.is_empty():
        return
    for command: SimulationCommand in commands:
        var result := _command_system.apply(state, command)
        state.last_events.append(result.code)
    state.revision += 1


func _validate_and_hash() -> String:
    var invariant_errors := _invariant_checker.check(state)
    if not invariant_errors.is_empty():
        var message := "Нарушены инварианты симуляции: %s" % [invariant_errors]
        push_error(message)
        assert(false, message)
        return ""
    return _hasher.hash_state(state)


func run_ticks(count: int) -> Array[String]:
    assert(count >= 0, "Количество тиков не может быть отрицательным")
    var hashes: Array[String] = []
    for _index in count:
        hashes.append(step())
    return hashes
