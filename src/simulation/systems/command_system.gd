class_name CommandSystem
extends RefCounted


func apply(state: SimulationState, command: SimulationCommand) -> CommandResult:
    if state == null or command == null:
        return CommandResult.rejected(&"invalid_command")
    if command.type != SimulationCommand.SET_BUILDING_PRIORITY:
        return CommandResult.rejected(&"unsupported_command", command.id)

    var building := state.get_building(command.building_id)
    if building == null:
        return CommandResult.rejected(&"unknown_building", command.id)
    if command.priority < 0 or command.priority > 4:
        return CommandResult.rejected(&"invalid_priority", command.id)

    building.priority = command.priority
    return CommandResult.success(command.id)
