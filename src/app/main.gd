extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var logistics_world_view: LogisticsWorldView = $World/LogisticsWorldView
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


func _ready() -> void:
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var load_result := ScenarioLoader.new().load_scenario(scenario)
    if not load_result.is_success():
        push_error("scenario_load_failed: %s" % [load_result.errors])
        return

    _runner = SimulationRunner.new(load_result.state)
    _map_state = _runner.state.map_state
    _hex_layout = HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(_map_state, _hex_layout)
    logistics_world_view.configure(_runner.state, _hex_layout)
    simulation_controller.configure(_runner)
    _selection_controller.configure(_runner.state, _hex_layout, logistics_world_view)
    _inspector_controller.configure($UI/RightPanel/Margin/VBox/Scroll/Inspector)
    _hud_controller.configure(_runner, simulation_controller, logistics_world_view.get_diagnostics_view(), {
        &"wood": $UI/TopBar/Margin/HBox/Wood,
        &"throughput": $UI/TopBar/Margin/HBox/Throughput,
        &"tick": $UI/TopBar/Margin/HBox/Tick,
        &"status": status_label,
    })
    _connect_ui()
    camera_controller.configure_bounds(grid_view.get_world_rect().grow(64.0))
    camera_controller.set_zoom_factor(0.75)


func get_runner() -> SimulationRunner:
    return _runner


func get_hud_controller() -> HUDController:
    return _hud_controller


func get_inspector_controller() -> InspectorController:
    return _inspector_controller


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
    $UI/BottomBar/Margin/Tools/Inspect.pressed.connect(_begin_inspect)
    $UI/BottomBar/Margin/Tools/Road.pressed.connect(_begin_road)
    $UI/BottomBar/Margin/Tools/Depot.pressed.connect(_begin_depot)
    $UI/BottomBar/Margin/Tools/Link.pressed.connect(_begin_link)


func _on_world_position_selected(local_position: Vector2) -> void:
    var kind := _selection_controller.select_at_local_position(local_position)
    var intent := _tool_controller.handle_selection(
        kind,
        _selection_controller.selected_id,
        _selection_controller.selected_coord
    )
    var code := intent.get(&"code", &"") as StringName
    if code == &"inspect":
        _inspector_controller.show_selection(_runner.state, kind, _selection_controller.selected_id)
        if _selection_controller.selected_coord != null:
            status_label.text = tr(&"ui.status.selected_hex").format({
                "q": _selection_controller.selected_coord.q,
                "r": _selection_controller.selected_coord.r,
            })
    elif code == &"link_origin":
        status_label.text = tr(&"ui.status.tool.link_destination")
    elif code != &"ignored":
        var result := _hud_controller.submit_intent(intent)
        status_label.text = _hud_controller.localized_command_message(result)


func _on_state_changed(state: SimulationState) -> void:
    grid_view.capture_tick(state.map_state)
    logistics_world_view.capture_tick(state)
    _selection_controller.capture_tick(state)
    _hud_controller.refresh(state)
    if not _selection_controller.selected_kind.is_empty():
        _inspector_controller.show_selection(state, _selection_controller.selected_kind, _selection_controller.selected_id)


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


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not (event as InputEventKey).pressed:
        return
    match (event as InputEventKey).keycode:
        KEY_1: _begin_inspect()
        KEY_2: _begin_road()
        KEY_3: _begin_depot()
        KEY_4: _begin_link()
        KEY_SPACE: _on_pause_pressed()
        KEY_ESCAPE:
            _tool_controller.cancel()
            status_label.text = tr(&"ui.status.tool.inspect")
