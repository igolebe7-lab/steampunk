class_name CommandSystem
extends RefCounted


func apply(state: SimulationState, command: SimulationCommand) -> CommandResult:
    if state == null or command == null:
        return CommandResult.rejected(&"invalid_command")
    if command.type != SimulationCommand.SET_BUILDING_PRIORITY:
        return CommandResult.rejected(&"unsupported_command")

    var building := state.get_building(command.building_id)
    if building == null:
        return CommandResult.rejected(&"unknown_building")
    if command.priority < 0 or command.priority > 4:
        return CommandResult.rejected(&"invalid_priority")

    building.priority = command.priority
    return CommandResult.success()
