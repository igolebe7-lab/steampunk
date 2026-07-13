class_name CameraController
extends Camera2D

@export var minimum_zoom: float = 0.5
@export var maximum_zoom: float = 2.0
@export var zoom_step: float = 1.15

var _dragging: bool = false
var _world_rect: Rect2


func set_zoom_factor(value: float) -> void:
    var clamped := clampf(value, minimum_zoom, maximum_zoom)
    zoom = Vector2.ONE * clamped


func configure_bounds(world_rect: Rect2) -> void:
    _world_rect = world_rect
    limit_left = floori(world_rect.position.x)
    limit_top = floori(world_rect.position.y)
    limit_right = ceili(world_rect.end.x)
    limit_bottom = ceili(world_rect.end.y)
    position = world_rect.get_center()
    reset_smoothing()


func pan_by(screen_delta: Vector2) -> void:
    var target := position - screen_delta / zoom.x
    position = target.clamp(_world_rect.position, _world_rect.end)


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
        pan_by(motion_event.relative)
        get_viewport().set_input_as_handled()
