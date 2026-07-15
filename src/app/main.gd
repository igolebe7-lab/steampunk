extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var logistics_world_view: LogisticsWorldView = $World/LogisticsWorldView
@onready var simulation_controller: SimulationController = $SimulationController
@onready var camera_controller: CameraController = $CameraController
@onready var title_label: Label = $UI/Margin/VBox/Title
@onready var status_label: Label = $UI/Margin/VBox/Status

var _map_state: HexMapState
var _hex_layout: HexLayout
var _runner: SimulationRunner


func _ready() -> void:
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")

    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var load_result := ScenarioLoader.new().load_scenario(scenario)
    if not load_result.is_success():
        push_error("Не удалось загрузить физическую логистику: %s" % [load_result.errors])
        return

    _runner = SimulationRunner.new(load_result.state)
    _map_state = _runner.state.map_state
    _hex_layout = HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(_map_state, _hex_layout)
    logistics_world_view.configure(_runner.state, _hex_layout)
    grid_view.hex_selected.connect(_on_hex_selected)
    simulation_controller.tick_completed.connect(_on_tick_completed)
    simulation_controller.interpolation_changed.connect(_on_interpolation_changed)
    simulation_controller.configure(_runner)

    camera_controller.configure_bounds(grid_view.get_world_rect().grow(64.0))
    camera_controller.set_zoom_factor(0.75)


func _on_hex_selected(coord: HexCoord) -> void:
    status_label.text = tr(&"ui.status.selected_hex").format({"q": coord.q, "r": coord.r})


func _on_tick_completed(state: SimulationState) -> void:
    grid_view.capture_tick(state.map_state)
    logistics_world_view.capture_tick(state)


func _on_interpolation_changed(alpha: float) -> void:
    logistics_world_view.set_interpolation(alpha)
