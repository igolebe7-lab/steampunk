class_name CommandQueue
extends RefCounted

var _commands_by_tick: Dictionary = {}
var _command_keys: Dictionary = {}


func enqueue(command: SimulationCommand, completed_tick: int) -> CommandResult:
    if command == null:
        return CommandResult.rejected(&"invalid_command")
    if command.target_tick <= completed_tick:
        return CommandResult.rejected(&"past_tick")

    var command_key := _key(command.target_tick, command.sequence)
    if _command_keys.has(command_key):
        return CommandResult.rejected(&"duplicate_sequence")

    if not _commands_by_tick.has(command.target_tick):
        _commands_by_tick[command.target_tick] = [] as Array[SimulationCommand]
    var tick_commands := _commands_by_tick[command.target_tick] as Array[SimulationCommand]
    tick_commands.append(command)
    _command_keys[command_key] = true
    return CommandResult.success()


func take_for_tick(tick: int) -> Array[SimulationCommand]:
    if not _commands_by_tick.has(tick):
        return []

    var result := _commands_by_tick[tick] as Array[SimulationCommand]
    _commands_by_tick.erase(tick)
    for command in result:
        _command_keys.erase(_key(command.target_tick, command.sequence))
    result.sort_custom(_sort_by_sequence)
    return result


func _key(target_tick: int, sequence: int) -> StringName:
    return StringName("%d:%d" % [target_tick, sequence])


func _sort_by_sequence(left: SimulationCommand, right: SimulationCommand) -> bool:
    return left.sequence < right.sequence
