class_name LogisticsWorldView
extends Node2D

var _layout: HexLayout
var _worker_views: Array[WorkerView] = []
var _building_views: Array[BuildingView] = []


func configure(state: SimulationState, layout: HexLayout) -> void:
    _layout = layout
    for child in get_children():
        child.free()
    _worker_views.clear()
    _building_views.clear()

    var building_ids: Array[int] = []
    for key: Variant in state.buildings.keys():
        building_ids.append(key as int)
    building_ids.sort()
    for building_id: int in building_ids:
        var building := state.get_building(building_id)
        var definition := state.catalog.get_building(building.definition_id)
        var view := BuildingView.new()
        add_child(view)
        view.position = layout.coord_to_pixel(building.coord)
        view.configure(building, definition)
        _building_views.append(view)

    var worker_ids: Array[int] = []
    for key: Variant in state.workers.keys():
        worker_ids.append(key as int)
    worker_ids.sort()
    for worker_id: int in worker_ids:
        var view := WorkerView.new()
        add_child(view)
        view.configure(state.get_worker(worker_id), layout)
        _worker_views.append(view)


func capture_tick(state: SimulationState) -> void:
    if _layout == null:
        return
    for view: WorkerView in _worker_views:
        var worker := state.get_worker(view.worker_id)
        if worker != null:
            view.capture_tick(worker, _layout)


func set_interpolation(alpha: float) -> void:
    for view: WorkerView in _worker_views:
        view.set_interpolation(alpha)


func get_worker_view_count() -> int:
    return _worker_views.size()


func get_building_view_count() -> int:
    return _building_views.size()


func get_worker_visual_position(index: int) -> Vector2:
    if index < 0 or index >= _worker_views.size():
        return Vector2(INF, INF)
    return _worker_views[index].get_visual_position()
