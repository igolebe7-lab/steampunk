extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var camera_controller: CameraController = $CameraController
@onready var title_label: Label = $UI/Margin/VBox/Title
@onready var status_label: Label = $UI/Margin/VBox/Status


func _ready() -> void:
    TranslationServer.set_locale("ru")
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")

    var map_state := HexMapState.new(18, 18)
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(map_state, layout)
    grid_view.hex_selected.connect(_on_hex_selected)

    camera_controller.configure_bounds(grid_view.get_world_rect().grow(64.0))
    camera_controller.set_zoom_factor(0.75)


func _on_hex_selected(coord: HexCoord) -> void:
    status_label.text = tr(&"ui.status.selected_hex").format({"q": coord.q, "r": coord.r})
