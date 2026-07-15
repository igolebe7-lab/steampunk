class_name HUDController
extends RefCounted

var _runner: SimulationRunner
var _simulation: SimulationController
var _diagnostics: DiagnosticsView
var _labels: Dictionary = {}
var _sequence: int = 1000


func configure(
    runner: SimulationRunner,
    simulation: SimulationController,
    diagnostics: DiagnosticsView,
    labels: Dictionary = {}
) -> void:
    _runner = runner
    _simulation = simulation
    _diagnostics = diagnostics
    _labels = labels
    refresh(runner.state)


func refresh(state: SimulationState) -> void:
    if state == null:
        return
    var main := state.get_building(state.main_warehouse_id)
    var wood := 0 if main == null else main.get_amount(&"wood")
    var throughput := state.telemetry_window.main_throughput_per_minute(&"wood")
    _set_label(&"wood", tr(&"ui.hud.wood").format({"value": wood}))
    _set_label(&"throughput", tr(&"ui.hud.throughput").format({"value": "%.1f" % throughput}))
    _set_label(&"tick", tr(&"ui.hud.tick").format({"value": state.tick}))
    var reason := state.diagnostic_report.code
    _set_label(&"status", tr(&"ui.status.select_hex") if reason.is_empty() else localized_reason(reason))


func set_paused(value: bool) -> void:
    _simulation.set_paused(value)


func set_speed_multiplier(value: int) -> bool:
    return _simulation.set_speed_multiplier(value)


func set_layer_visible(layer: StringName, visible: bool) -> bool:
    return _diagnostics.set_layer_visible(layer, visible)


func submit_intent(intent: Dictionary) -> StringName:
    if _runner == null or _simulation == null:
        return &"invalid_command"
    var target_tick := _runner.state.tick + 1
    _sequence += 1
    var command: SimulationCommand
    match intent.get(&"code", &"") as StringName:
        &"road_cell":
            command = BuildRoadCommand.new(target_tick, _sequence, [intent.get(&"coord")])
        &"depot_cell":
            command = DepotCommand.place(target_tick, _sequence, intent.get(&"coord") as HexCoord)
        &"link_complete":
            command = LinkCommand.create(
                target_tick,
                _sequence,
                intent.get(&"source_id", 0) as int,
                intent.get(&"destination_id", 0) as int,
                &"wood"
            )
        &"link_settings":
            command = LinkSettingsCommand.new(
                target_tick,
                _sequence,
                intent.get(&"link_id", 0) as int,
                intent.get(&"quota", 0) as int,
                intent.get(&"priority", 0) as int,
                intent.get(&"dispatch_enabled", true) as bool
            )
        &"dispatch_policy":
            command = DispatchPolicyCommand.new(
                target_tick,
                _sequence,
                intent.get(&"building_id", 0) as int,
                intent.get(&"allows_direct", true) as bool
            )
        &"remove_link":
            command = LinkCommand.remove(
                target_tick,
                _sequence,
                intent.get(&"link_id", 0) as int
            )
        &"reset_link":
            command = LinkCommand.reset_automatic(
                target_tick,
                _sequence,
                intent.get(&"source_id", 0) as int,
                intent.get(&"resource_id", &"wood") as StringName
            )
        &"demolish_depot":
            command = DepotCommand.demolish(
                target_tick,
                _sequence,
                intent.get(&"building_id", 0) as int
            )
        _:
            return &"invalid_command"
    var queued := _runner.enqueue(command)
    if not queued.accepted:
        return queued.code
    _simulation.flush_commands()
    refresh(_runner.state)
    return &"accepted" if _runner.state.last_events.is_empty() else _runner.state.last_events[-1]


func localized_reason(code: StringName) -> String:
    if code.is_empty():
        return tr(&"ui.value.none")
    return tr(StringName("reason.%s" % code))


func localized_command_message(code: StringName) -> String:
    var key := StringName("command.%s" % code)
    var translated := tr(key)
    return tr(&"command.unknown") if translated == String(key) else translated


func _set_label(key: StringName, value: String) -> void:
    var label := _labels.get(key) as Label
    if label != null:
        label.text = value
