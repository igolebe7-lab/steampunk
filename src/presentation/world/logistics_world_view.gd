class_name LogisticsWorldView
extends Node2D

var _layout: HexLayout
var _worker_views: Dictionary = {}
var _building_views: Dictionary = {}
var _diagnostics_view: DiagnosticsView
var _utility_network_view: UtilityNetworkView


func configure(state: SimulationState, layout: HexLayout) -> void:
    _layout = layout
    for child in get_children():
        child.free()
    _worker_views.clear()
    _building_views.clear()
    _diagnostics_view = DiagnosticsView.new()
    add_child(_diagnostics_view)
    _diagnostics_view.configure(state, layout)
    _utility_network_view = UtilityNetworkView.new()
    add_child(_utility_network_view)
    _utility_network_view.configure(state, layout)
    _sync_buildings(state)
    _sync_workers(state, true)


func capture_tick(state: SimulationState) -> void:
    if _layout == null:
        return
    _sync_buildings(state)
    _sync_workers(state, false)
    _diagnostics_view.capture_tick(state)
    _utility_network_view.capture_tick(state)


func set_interpolation(alpha: float) -> void:
    for view: WorkerView in _worker_views.values():
        view.set_interpolation(alpha)


func get_worker_view_count() -> int:
    return _worker_views.size()


func get_building_view_count() -> int:
    return _building_views.size()


func has_building_view(building_id: int) -> bool:
    return _building_views.has(building_id)


func get_diagnostics_view() -> DiagnosticsView:
    return _diagnostics_view


func get_utility_network_view() -> UtilityNetworkView:
    return _utility_network_view


func set_utility_layer_visible(value: bool) -> void:
    if _utility_network_view != null:
        _utility_network_view.visible = value


func hit_test_worker(local_position: Vector2, radius: float = 14.0) -> int:
    for worker_id: int in _sorted_ids(_worker_views):
        var view := _worker_views[worker_id] as WorkerView
        if view.get_visual_position().distance_to(local_position) <= radius:
            return worker_id
    return 0


func hit_test_building(local_position: Vector2, radius: float = 28.0) -> int:
    for building_id: int in _sorted_ids(_building_views):
        var view := _building_views[building_id] as BuildingView
        if view.position.distance_to(local_position) <= radius:
            return building_id
    return 0


func get_worker_visual_position(index: int) -> Vector2:
    var ids := _sorted_ids(_worker_views)
    if index < 0 or index >= ids.size():
        return Vector2(INF, INF)
    return (_worker_views[ids[index]] as WorkerView).get_visual_position()


func _sync_buildings(state: SimulationState) -> void:
    for id_value: Variant in _building_views.keys():
        var building_id := id_value as int
        if not state.buildings.has(building_id):
            (_building_views[building_id] as BuildingView).free()
            _building_views.erase(building_id)
    for building_id: int in _sorted_ids(state.buildings):
        var building := state.get_building(building_id)
        var definition := state.catalog.get_building(building.definition_id)
        var view := _building_views.get(building_id) as BuildingView
        if view == null:
            view = BuildingView.new()
            add_child(view)
            _building_views[building_id] = view
            view.position = _layout.coord_to_pixel(building.coord)
            view.configure(building, definition)


func _sync_workers(state: SimulationState, initial: bool) -> void:
    for id_value: Variant in _worker_views.keys():
        var worker_id := id_value as int
        if not state.workers.has(worker_id):
            (_worker_views[worker_id] as WorkerView).free()
            _worker_views.erase(worker_id)
    for worker_id: int in _sorted_ids(state.workers):
        var worker := state.get_worker(worker_id)
        var view := _worker_views.get(worker_id) as WorkerView
        if view == null:
            view = WorkerView.new()
            add_child(view)
            view.configure(worker, _layout)
            _worker_views[worker_id] = view
        elif not initial:
            view.capture_tick(worker, _layout)


func _sorted_ids(values: Dictionary) -> Array[int]:
    var result: Array[int] = []
    for key: Variant in values.keys():
        result.append(key as int)
    result.sort()
    return result
