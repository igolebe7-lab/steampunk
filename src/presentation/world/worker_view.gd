class_name WorkerView
extends Node2D

const BODY_COLOR := Color("#c8b18a")
const BODY_OUTLINE := Color("#283339")
const CARGO_COLOR := Color("#69a65d")
const WAIT_COLOR := Color("#d7973e")
const BLOCKED_COLOR := Color("#c55245")

var worker_id: int

var _previous_position := Vector2.ZERO
var _current_position := Vector2.ZERO
var _direction := Vector2.RIGHT
var _has_cargo := false
var _is_waiting := false
var _is_blocked := false


func configure(worker: WorkerState, layout: HexLayout) -> void:
    worker_id = worker.id
    _current_position = layout.coord_to_pixel(worker.coord)
    _previous_position = _current_position
    position = _current_position
    _capture_state(worker, layout)


func capture_tick(worker: WorkerState, layout: HexLayout) -> void:
    _previous_position = _current_position
    _current_position = layout.coord_to_pixel(worker.coord)
    _capture_state(worker, layout)


func set_interpolation(alpha: float) -> void:
    position = _previous_position.lerp(_current_position, clampf(alpha, 0.0, 1.0))


func get_visual_position() -> Vector2:
    return position


func _capture_state(worker: WorkerState, layout: HexLayout) -> void:
    var target: HexCoord = worker.segment_target
    if target == null and worker.route_index + 1 < worker.route.size():
        target = worker.route[worker.route_index + 1]
    if target != null:
        var vector := layout.coord_to_pixel(target) - layout.coord_to_pixel(worker.coord)
        if not vector.is_zero_approx():
            _direction = vector.normalized()
    _has_cargo = not worker.cargo_resource_id.is_empty()
    _is_waiting = not worker.wait_reason.is_empty() and worker.wait_reason != &"no_job"
    _is_blocked = worker.action == WorkerState.BLOCKED
    queue_redraw()


func _draw() -> void:
    var outline := BLOCKED_COLOR if _is_blocked else (WAIT_COLOR if _is_waiting else BODY_OUTLINE)
    draw_circle(Vector2.ZERO, 11.0, outline)
    draw_circle(Vector2.ZERO, 8.0, BODY_COLOR)
    draw_line(Vector2.ZERO, _direction * 13.0, BODY_OUTLINE, 3.0, true)
    var side := Vector2(-_direction.y, _direction.x)
    draw_colored_polygon(PackedVector2Array([
        _direction * 15.0,
        _direction * 9.0 + side * 4.0,
        _direction * 9.0 - side * 4.0,
    ]), BODY_OUTLINE)
    if _has_cargo:
        draw_rect(Rect2(5.0, 3.0, 8.0, 8.0), CARGO_COLOR, true)
        draw_rect(Rect2(5.0, 3.0, 8.0, 8.0), BODY_OUTLINE, false, 1.0)
