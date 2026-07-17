class_name ResponsiveLayoutController
extends RefCounted

var _world_space: Control
var _camera: CameraController
var _world_rect := Rect2()
var _viewport_size := Vector2.ZERO
var _revision := 0


func configure(world_space: Control, camera: CameraController) -> void:
    _world_space = world_space
    _camera = camera


func refresh(viewport_size: Vector2, fit_world: bool = false) -> bool:
    if (
        _world_space == null
        or _camera == null
        or viewport_size.x <= 0.0
        or viewport_size.y <= 0.0
    ):
        return false
    var next_rect := _world_space.get_global_rect()
    if (
        next_rect.is_equal_approx(_world_rect)
        and viewport_size.is_equal_approx(_viewport_size)
    ):
        return false
    _world_rect = next_rect
    _viewport_size = viewport_size
    _revision += 1
    _camera.configure_safe_view(_world_rect, _viewport_size, fit_world)
    return true


func snapshot() -> Dictionary:
    return {
        &"world_rect": _world_rect,
        &"viewport_size": _viewport_size,
        &"revision": _revision,
    }
