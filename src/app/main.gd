extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var logistics_world_view: LogisticsWorldView = $World/LogisticsWorldView
@onready var industrial_effects_view: IndustrialEffectsView = $World/IndustrialEffectsView
@onready var simulation_controller: SimulationController = $SimulationController
@onready var camera_controller: CameraController = $CameraController
@onready var title_label: Label = $UI/TopBar/Margin/HBox/Title
@onready var status_label: Label = $UI/TopBar/Margin/HBox/Status

var _map_state: HexMapState
var _hex_layout: HexLayout
var _runner: SimulationRunner
var _hud_controller := HUDController.new()
var _inspector_controller := InspectorController.new()
var _selection_controller := SelectionController.new()
var _tool_controller := ToolController.new()
var _result_panel_controller := ResultPanelController.new()
var _playtest_recorder: PlaytestRecorder
var _playtest_storage: PlaytestStorage
var _playtest_writer: PlaytestReportWriter
var _playtest_analyzer: PlaytestMilestoneAnalyzer


func _ready() -> void:
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")
    var scenario := load("res://data/scenarios/full_industrial.tres") as ScenarioDef
    var load_result := ScenarioLoader.new().load_scenario(scenario)
    if not load_result.is_success():
        push_error("scenario_load_failed: %s" % [load_result.errors])
        return

    _runner = SimulationRunner.new(load_result.state, false)
    _map_state = _runner.state.map_state
    _hex_layout = HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(_map_state, _hex_layout)
    logistics_world_view.configure(_runner.state, _hex_layout)
    industrial_effects_view.configure(_hex_layout)
    simulation_controller.configure(_runner)
    _selection_controller.configure(_runner.state, _hex_layout, logistics_world_view)
    _inspector_controller.configure($UI/RightPanel/Margin/VBox/Scroll/Inspector, {
        &"link_controls": $UI/RightPanel/Margin/VBox/LinkControls,
        &"quota": $UI/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota,
        &"priority": $UI/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority,
        &"dispatch": $UI/RightPanel/Margin/VBox/LinkControls/Dispatch,
        &"building_controls": $UI/RightPanel/Margin/VBox/BuildingControls,
        &"direct_main": $UI/RightPanel/Margin/VBox/BuildingControls/DirectMain,
        &"apply_direct": $UI/RightPanel/Margin/VBox/BuildingControls/ApplyDirect,
        &"demolish": $UI/RightPanel/Margin/VBox/BuildingControls/Demolish,
    })
    _hud_controller.configure(_runner, simulation_controller, logistics_world_view.get_diagnostics_view(), {
        &"wood": $UI/TopBar/Margin/HBox/Wood,
        &"throughput": $UI/TopBar/Margin/HBox/Throughput,
        &"tick": $UI/TopBar/Margin/HBox/Tick,
        &"status": status_label,
        &"phase": $UI/LeftPanel/Margin/Layers/Phase,
    }, logistics_world_view)
    _result_panel_controller.configure(
        $UI/ResultPanel,
        $UI/ResultPanel/Margin/VBox/Title,
        $UI/ResultPanel/Margin/VBox/Metrics,
        $UI/ResultPanel/Margin/VBox/Continue
    )
    _connect_ui()
    _configure_playtest_from_args()
    camera_controller.configure_bounds(grid_view.get_world_rect().grow(64.0))
    camera_controller.set_zoom_factor(0.75)
    _hud_controller.refresh(_runner.state)


func get_runner() -> SimulationRunner:
    return _runner


func get_hud_controller() -> HUDController:
    return _hud_controller


func get_inspector_controller() -> InspectorController:
    return _inspector_controller


func get_result_panel_controller() -> ResultPanelController:
    return _result_panel_controller


func get_playtest_recorder() -> PlaytestRecorder:
    return _playtest_recorder


func configure_playtest_for_test(
    recorder: PlaytestRecorder,
    storage: PlaytestStorage
) -> void:
    _attach_playtest(recorder, storage)


func get_diagnostics_view() -> DiagnosticsView:
    return logistics_world_view.get_diagnostics_view()


func _connect_ui() -> void:
    grid_view.local_position_selected.connect(_on_world_position_selected)
    simulation_controller.tick_completed.connect(_on_state_changed)
    simulation_controller.commands_flushed.connect(_on_state_changed)
    simulation_controller.interpolation_changed.connect(_on_interpolation_changed)
    $UI/TopBar/Margin/HBox/Pause.pressed.connect(_on_pause_pressed)
    $UI/TopBar/Margin/HBox/Speed1.pressed.connect(func() -> void: _hud_controller.set_speed_multiplier(1))
    $UI/TopBar/Margin/HBox/Speed2.pressed.connect(func() -> void: _hud_controller.set_speed_multiplier(2))
    $UI/TopBar/Margin/HBox/Speed4.pressed.connect(func() -> void: _hud_controller.set_speed_multiplier(4))
    $UI/LeftPanel/Margin/Layers/Links.toggled.connect(func(value: bool) -> void: _hud_controller.set_layer_visible(&"links", value))
    $UI/LeftPanel/Margin/Layers/Routes.toggled.connect(func(value: bool) -> void: _hud_controller.set_layer_visible(&"routes", value))
    $UI/LeftPanel/Margin/Layers/Load.toggled.connect(func(value: bool) -> void: _hud_controller.set_layer_visible(&"load", value))
    $UI/LeftPanel/Margin/Layers/Utilities.toggled.connect(func(value: bool) -> void: _hud_controller.set_layer_visible(&"utilities", value))
    $UI/BottomBar/Margin/Tools/Inspect.pressed.connect(_begin_inspect)
    $UI/BottomBar/Margin/Tools/Road.pressed.connect(_begin_road)
    $UI/BottomBar/Margin/Tools/Depot.pressed.connect(_begin_depot)
    $UI/BottomBar/Margin/Tools/Link.pressed.connect(_begin_link)
    $UI/BottomBar/Margin/Tools/PipeBuild.pressed.connect(_begin_pipe_build)
    $UI/BottomBar/Margin/Tools/PipeRemove.pressed.connect(_begin_pipe_remove)
    $UI/RightPanel/Margin/VBox/LinkControls/Apply.pressed.connect(_apply_link_settings)
    $UI/RightPanel/Margin/VBox/LinkControls/Remove.pressed.connect(_remove_selected_link)
    $UI/RightPanel/Margin/VBox/LinkControls/Reset.pressed.connect(_reset_selected_link)
    $UI/RightPanel/Margin/VBox/BuildingControls/ApplyDirect.pressed.connect(_apply_dispatch_policy)
    $UI/RightPanel/Margin/VBox/BuildingControls/Demolish.pressed.connect(_demolish_selected_depot)


func _on_world_position_selected(local_position: Vector2) -> void:
    var kind := _selection_controller.select_at_local_position(local_position)
    var intent := _tool_controller.handle_selection(
        kind,
        _selection_controller.selected_id,
        _selection_controller.selected_coord
    )
    var code := intent.get(&"code", &"") as StringName
    if code == &"inspect":
        _inspector_controller.show_selection(
            _runner.state,
            kind,
            _selection_controller.selected_id,
            _selection_controller.selected_coord
        )
        if _selection_controller.selected_coord != null:
            status_label.text = tr(&"ui.status.selected_hex").format({
                "q": _selection_controller.selected_coord.q,
                "r": _selection_controller.selected_coord.r,
            })
    elif code == &"link_origin":
        status_label.text = tr(&"ui.status.tool.link_destination")
    elif code == &"pipe_preview":
        status_label.text = tr(&"ui.status.tool.pipe_preview").format({
            "segments": (intent.get(&"cells", []) as Array).size(),
            "cost": intent.get(&"cost", 0),
        })
    elif code != &"ignored":
        var result := _hud_controller.submit_intent(intent)
        status_label.text = _hud_controller.localized_command_message(result)


func _on_state_changed(state: SimulationState) -> void:
    grid_view.capture_tick(state.map_state)
    logistics_world_view.capture_tick(state)
    industrial_effects_view.capture_tick(state)
    _selection_controller.capture_tick(state)
    _hud_controller.refresh(state)
    _result_panel_controller.refresh(state)
    if not _selection_controller.selected_kind.is_empty():
        _inspector_controller.show_selection(
            state,
            _selection_controller.selected_kind,
            _selection_controller.selected_id,
            _selection_controller.selected_coord
        )
    if _playtest_recorder != null:
        _playtest_recorder.capture_state(state)
        if state.scenario_progress.phase == ScenarioProgressState.COMPLETED:
            _playtest_recorder.finish(&"completed", state)


func _on_interpolation_changed(alpha: float) -> void:
    logistics_world_view.set_interpolation(alpha)


func _on_pause_pressed() -> void:
    var paused := not simulation_controller.is_paused()
    _hud_controller.set_paused(paused)
    ($UI/TopBar/Margin/HBox/Pause as Button).text = tr(&"ui.hud.resume") if paused else tr(&"ui.hud.pause")


func _begin_inspect() -> void:
    _tool_controller.cancel()
    status_label.text = tr(&"ui.status.tool.inspect")


func _begin_road() -> void:
    _tool_controller.begin_road()
    status_label.text = tr(&"ui.status.tool.road")


func _begin_depot() -> void:
    _tool_controller.begin_depot()
    status_label.text = tr(&"ui.status.tool.depot")


func _begin_link() -> void:
    _tool_controller.begin_link()
    status_label.text = tr(&"ui.status.tool.link")


func _begin_pipe_build() -> void:
    if _tool_controller.mode == ToolController.PIPE_BUILD:
        _submit_pipe_preview()
        return
    _tool_controller.begin_pipe_build()
    status_label.text = tr(&"ui.status.tool.pipe_build")


func _begin_pipe_remove() -> void:
    if _tool_controller.mode == ToolController.PIPE_REMOVE:
        _submit_pipe_preview()
        return
    _tool_controller.begin_pipe_remove()
    status_label.text = tr(&"ui.status.tool.pipe_remove")


func _submit_pipe_preview() -> void:
    var intent := _tool_controller.finish_pipe()
    if (intent.get(&"code", &"ignored") as StringName) == &"ignored":
        return
    var result := _hud_controller.submit_intent(intent)
    status_label.text = _hud_controller.localized_command_message(result)


func _apply_link_settings() -> void:
    if _inspector_controller.selected_kind != &"link":
        return
    _submit_inspector_intent({
        &"code": &"link_settings",
        &"link_id": _inspector_controller.selected_id,
        &"quota": int(($UI/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota as SpinBox).value),
        &"priority": int(($UI/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority as SpinBox).value),
        &"dispatch_enabled": ($UI/RightPanel/Margin/VBox/LinkControls/Dispatch as CheckButton).button_pressed,
    })


func _remove_selected_link() -> void:
    if _inspector_controller.selected_kind == &"link":
        _submit_inspector_intent({&"code": &"remove_link", &"link_id": _inspector_controller.selected_id})


func _reset_selected_link() -> void:
    if _inspector_controller.selected_kind != &"link":
        return
    var link := _runner.state.logistics_links.get(_inspector_controller.selected_id) as LogisticsLinkState
    if link != null:
        _submit_inspector_intent({
            &"code": &"reset_link",
            &"source_id": link.source_id,
            &"resource_id": link.resource_id,
        })


func _apply_dispatch_policy() -> void:
    if _inspector_controller.selected_kind != &"building":
        return
    _submit_inspector_intent({
        &"code": &"dispatch_policy",
        &"building_id": _inspector_controller.selected_id,
        &"allows_direct": ($UI/RightPanel/Margin/VBox/BuildingControls/DirectMain as CheckButton).button_pressed,
    })


func _demolish_selected_depot() -> void:
    if _inspector_controller.selected_kind == &"building":
        _submit_inspector_intent({
            &"code": &"demolish_depot",
            &"building_id": _inspector_controller.selected_id,
        })


func _submit_inspector_intent(intent: Dictionary) -> void:
    var result := _hud_controller.submit_intent(intent)
    status_label.text = _hud_controller.localized_command_message(result)


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not (event as InputEventKey).pressed:
        return
    match (event as InputEventKey).keycode:
        KEY_1: _begin_inspect()
        KEY_2: _begin_road()
        KEY_3: _begin_depot()
        KEY_4: _begin_link()
        KEY_5: _begin_pipe_build()
        KEY_6: _begin_pipe_remove()
        KEY_SPACE: _on_pause_pressed()
        KEY_ESCAPE:
            _tool_controller.cancel()
            status_label.text = tr(&"ui.status.tool.inspect")


func _exit_tree() -> void:
    if _playtest_recorder != null and not _playtest_recorder.session.is_finished():
        _playtest_recorder.finish(&"aborted", null if _runner == null else _runner.state)


func _configure_playtest_from_args() -> void:
    var fallback := ProjectSettings.get_setting(
        "application/config/version", "dev"
    ) as String
    var options := PlaytestLaunchOptions.parse(OS.get_cmdline_user_args(), fallback)
    if not options.error_code.is_empty():
        push_error(tr(StringName("playtest.error.%s" % options.error_code)))
        return
    if not options.enabled:
        return
    var storage := PlaytestStorage.new()
    if storage.has_final_result(options.session_id):
        push_error(tr(&"playtest.error.result_exists"))
        return
    var recovered := storage.load_latest_checkpoint(options.session_id)
    if recovered.get("ok", false) as bool:
        _finalize_recovered_session(recovered["data"] as Dictionary, storage)
        push_error(tr(&"playtest.error.recovered_interrupted"))
        return
    var session := PlaytestSession.new(
        options.session_id,
        options.build_revision,
        int(Time.get_unix_time_from_system() * 1000.0)
    )
    var recorder := PlaytestRecorder.new()
    recorder.configure(session)
    _attach_playtest(recorder, storage)


func _attach_playtest(recorder: PlaytestRecorder, storage: PlaytestStorage) -> void:
    if recorder == null or storage == null or _playtest_recorder != null:
        return
    _playtest_recorder = recorder
    _playtest_storage = storage
    _playtest_writer = PlaytestReportWriter.new()
    _playtest_analyzer = PlaytestMilestoneAnalyzer.new()
    _selection_controller.selection_changed.connect(_on_playtest_selection_changed)
    _tool_controller.mode_changed.connect(_on_playtest_tool_mode_changed)
    simulation_controller.pause_changed.connect(_on_playtest_pause_changed)
    simulation_controller.speed_changed.connect(_on_playtest_speed_changed)
    _hud_controller.layer_visibility_changed.connect(_on_playtest_layer_visibility_changed)
    _hud_controller.intent_resolved.connect(_on_playtest_intent_resolved)
    recorder.checkpoint_requested.connect(_on_playtest_checkpoint_requested)
    recorder.finished.connect(_on_playtest_finished)
    print("PLAYTEST_OUTPUT=%s" % storage.global_root_path())


func _on_playtest_selection_changed(
    kind: StringName,
    entity_id: int,
    coord: HexCoord
) -> void:
    _playtest_recorder.record_action(_runner.state.tick, &"ui", &"selection", {
        &"kind": kind,
        &"entity_id": entity_id,
        &"coord": coord,
    })


func _on_playtest_tool_mode_changed(mode: StringName) -> void:
    _playtest_recorder.record_action(_runner.state.tick, &"ui", mode)


func _on_playtest_pause_changed(paused: bool) -> void:
    _playtest_recorder.record_action(_runner.state.tick, &"ui", &"pause", {
        &"paused": paused,
    })


func _on_playtest_speed_changed(multiplier: int) -> void:
    _playtest_recorder.record_action(_runner.state.tick, &"ui", &"speed", {
        &"multiplier": multiplier,
    })


func _on_playtest_layer_visibility_changed(
    layer: StringName,
    visible: bool
) -> void:
    _playtest_recorder.record_action(_runner.state.tick, &"ui", &"layer_visibility", {
        &"layer": layer,
        &"visible": visible,
    })


func _on_playtest_intent_resolved(
    intent_code: StringName,
    result_code: StringName,
    payload: Dictionary
) -> void:
    _playtest_recorder.record_command(
        _runner.state,
        intent_code,
        result_code,
        payload
    )


func _on_playtest_checkpoint_requested(session: PlaytestSession) -> void:
    if _playtest_storage == null:
        return
    var analysis := _playtest_analyzer.analyze(session)
    var result := _playtest_storage.write_checkpoint(
        session,
        _playtest_writer.build_json(session, analysis)
    )
    if not (result.get("ok", false) as bool):
        _report_playtest_storage_error(result)


func _on_playtest_finished(session: PlaytestSession) -> void:
    if _playtest_storage == null:
        return
    var analysis := _playtest_analyzer.analyze(session)
    var result := _playtest_storage.write_final(
        session,
        _playtest_writer.build_json(session, analysis),
        _playtest_writer.build_markdown(session, analysis, &"ru")
    )
    if result.get("ok", false) as bool:
        _playtest_storage.clear_checkpoints(session.id)
    else:
        _report_playtest_storage_error(result)


func _finalize_recovered_session(data: Dictionary, storage: PlaytestStorage) -> void:
    var session := PlaytestSession.from_dictionary(data.get("session", {}) as Dictionary)
    if session == null:
        _report_playtest_storage_error({"error": "storage_write"})
        return
    var last_elapsed := session.ended_elapsed_ms
    var last_tick := session.ended_tick
    if not session.entries.is_empty():
        last_elapsed = session.entries[-1].elapsed_ms
        last_tick = session.entries[-1].tick
    session.finish(&"aborted", last_elapsed, last_tick)
    var analyzer := PlaytestMilestoneAnalyzer.new()
    var writer := PlaytestReportWriter.new()
    var analysis := analyzer.analyze(session)
    var result := storage.write_final(
        session,
        writer.build_json(session, analysis),
        writer.build_markdown(session, analysis, &"ru")
    )
    if result.get("ok", false) as bool:
        storage.clear_checkpoints(session.id)
    else:
        _report_playtest_storage_error(result)


func _report_playtest_storage_error(result: Dictionary) -> void:
    var error := result.get("error", "storage_write") as String
    if error not in ["storage_write", "report_too_large", "result_exists"]:
        error = "storage_write"
    push_error(tr(StringName("playtest.error.%s" % error)))
