class_name LinkSettingsCommand
extends SimulationCommand

var link_id: int
var quota: int
var priority: int
var dispatch_enabled: bool


func _init(
    p_target_tick: int,
    p_sequence: int,
    p_link_id: int,
    p_quota: int,
    p_priority: int,
    p_dispatch_enabled: bool = true
) -> void:
    super(SimulationCommand.SET_LINK_SETTINGS, p_target_tick, p_sequence)
    link_id = p_link_id
    quota = p_quota
    priority = p_priority
    dispatch_enabled = p_dispatch_enabled


func snapshot() -> SimulationCommand:
    return LinkSettingsCommand.new(
        target_tick,
        sequence,
        link_id,
        quota,
        priority,
        dispatch_enabled
    )
