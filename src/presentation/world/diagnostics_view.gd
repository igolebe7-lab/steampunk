class_name DiagnosticsView
extends Node2D

const AUTO_COLOR := Color("#6f9f91")
const MANUAL_COLOR := Color("#d2a04e")
const ROUTE_COLOR := Color("#8ca7bd")
const WAIT_COLOR := Color("#d7973e")
const BLOCKED_COLOR := Color("#c55245")

var _layout: HexLayout
var _link_visuals: Array[Dictionary] = []
var _route_visuals: Array[PackedVector2Array] = []
var _status_visuals: Array[Dictionary] = []
var _load_visuals: Array[Dictionary] = []
var _layers := {&"links": true, &"routes": true, &"load": true, &"statuses": true}


func configure(state: SimulationState, layout: HexLayout) -> void:
    _layout = layout
    capture_tick(state)


func capture_tick(state: SimulationState) -> void:
    if _layout == null:
        return
    _link_visuals.clear()
    _route_visuals.clear()
    _status_visuals.clear()
    _load_visuals.clear()
    var link_ids: Array[int] = []
    for key: Variant in state.logistics_links.keys():
        link_ids.append(key as int)
    link_ids.sort()
    for link_id: int in link_ids:
        var link := state.logistics_links[link_id] as LogisticsLinkState
        var source := state.get_building(link.source_id)
        var destination := state.get_building(link.destination_id)
        if source == null or destination == null:
            continue
        var start := _layout.coord_to_pixel(source.coord)
        var finish := _layout.coord_to_pixel(destination.coord)
        _link_visuals.append({
            &"id": link.id,
            &"start": start,
            &"finish": finish,
            &"automatic": link.is_automatic,
        })
        var workers := 0
        for worker_value: Variant in state.workers.values():
            if (worker_value as WorkerState).link_id == link.id:
                workers += 1
        _load_visuals.append({
            &"position": start.lerp(finish, 0.5),
            &"ratio": 0.0 if link.quota <= 0 else float(workers) / float(link.quota),
        })
    var worker_ids: Array[int] = []
    for key: Variant in state.workers.keys():
        worker_ids.append(key as int)
    worker_ids.sort()
    for worker_id: int in worker_ids:
        var worker := state.get_worker(worker_id)
        if worker.route.size() > 1:
            var points: PackedVector2Array = []
            for coord: HexCoord in worker.route:
                points.append(_layout.coord_to_pixel(coord))
            _route_visuals.append(points)
        if worker.action == WorkerState.BLOCKED or (
            not worker.wait_reason.is_empty() and worker.wait_reason != &"no_job"
        ):
            _status_visuals.append({
                &"position": _layout.coord_to_pixel(worker.coord),
                &"blocked": worker.action == WorkerState.BLOCKED,
            })
    queue_redraw()


func set_layer_visible(layer: StringName, visible: bool) -> bool:
    if not _layers.has(layer):
        return false
    _layers[layer] = visible
    queue_redraw()
    return true


func is_layer_visible(layer: StringName) -> bool:
    return _layers.get(layer, false) as bool


func get_link_visual_count() -> int:
    return _link_visuals.size()


func get_route_visual_count() -> int:
    return _route_visuals.size()


func get_status_visual_count() -> int:
    return _status_visuals.size()


func get_link_load_visual_count() -> int:
    return _load_visuals.size()


func hit_test_link(local_position: Vector2, tolerance: float = 8.0) -> int:
    for visual: Dictionary in _link_visuals:
        if _distance_to_segment(local_position, visual[&"start"], visual[&"finish"]) <= tolerance:
            return visual[&"id"] as int
    return 0


func _draw() -> void:
    if is_layer_visible(&"links"):
        for visual: Dictionary in _link_visuals:
            var color := AUTO_COLOR if (visual[&"automatic"] as bool) else MANUAL_COLOR
            if visual[&"automatic"] as bool:
                draw_dashed_line(visual[&"start"], visual[&"finish"], color, 3.0, 10.0, true)
            else:
                draw_line(visual[&"start"], visual[&"finish"], color, 4.0, true)
    if is_layer_visible(&"routes"):
        for points: PackedVector2Array in _route_visuals:
            draw_polyline(points, ROUTE_COLOR, 2.0, true)
    if is_layer_visible(&"load"):
        for visual: Dictionary in _load_visuals:
            draw_circle(visual[&"position"], 4.0 + 6.0 * clampf(visual[&"ratio"], 0.0, 1.0), MANUAL_COLOR)
    if is_layer_visible(&"statuses"):
        for visual: Dictionary in _status_visuals:
            draw_arc(visual[&"position"], 16.0, 0.0, TAU, 24, BLOCKED_COLOR if visual[&"blocked"] else WAIT_COLOR, 3.0, true)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment := finish - start
    if segment.is_zero_approx():
        return point.distance_to(start)
    var t := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
    return point.distance_to(start + segment * t)
