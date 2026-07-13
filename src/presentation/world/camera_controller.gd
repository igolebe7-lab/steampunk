class_name CameraController
extends Camera2D

@export var minimum_zoom: float = 0.5
@export var maximum_zoom: float = 2.0
@export var zoom_step: float = 1.15

var _dragging: bool = false


func set_zoom_factor(value: float) -> void:
    var clamped := clampf(value, minimum_zoom, maximum_zoom)
    zoom = Vector2.ONE * clamped


func configure_bounds(world_rect: Rect2) -> void:
    limit_left = floori(world_rect.position.x)
    limit_top = floori(world_rect.position.y)
    limit_right = ceili(world_rect.end.x)
    limit_bottom = ceili(world_rect.end.y)
    position = world_rect.get_center()
    reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        match mouse_event.button_index:
            MOUSE_BUTTON_MIDDLE:
                _dragging = mouse_event.pressed
                get_viewport().set_input_as_handled()
            MOUSE_BUTTON_WHEEL_UP:
                if mouse_event.pressed:
                    set_zoom_factor(zoom.x * zoom_step)
                    get_viewport().set_input_as_handled()
            MOUSE_BUTTON_WHEEL_DOWN:
                if mouse_event.pressed:
                    set_zoom_factor(zoom.x / zoom_step)
                    get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _dragging:
        var motion_event := event as InputEventMouseMotion
        position -= motion_event.relative / zoom.x
        get_viewport().set_input_as_handled()
