class_name SelectionController
extends RefCounted

signal selection_changed(kind: StringName, entity_id: int, coord: HexCoord)

var selected_kind: StringName = &""
var selected_id: int = 0
var selected_coord: HexCoord

var _state: SimulationState
var _layout: HexLayout
var _world: LogisticsWorldView


func configure(state: SimulationState, layout: HexLayout, world: LogisticsWorldView) -> void:
    _state = state
    _layout = layout
    _world = world


func capture_tick(state: SimulationState) -> void:
    _state = state


func select_at_local_position(local_position: Vector2) -> StringName:
    if _state == null or _layout == null or _world == null:
        return &""
    var coord := _layout.pixel_to_coord(local_position)
    var worker_id := _world.hit_test_worker(local_position)
    var building_id := _world.hit_test_building(local_position)
    var utility_coord := _world.get_utility_network_view().hit_test_segment(local_position)
    var link_id := _world.get_diagnostics_view().hit_test_link(local_position)
    return resolve_hit(
        worker_id,
        building_id,
        link_id,
        coord if _state.map_state.contains(coord) else null,
        utility_coord
    )


func resolve_hit(
    worker_id: int,
    building_id: int,
    link_id: int,
    coord: HexCoord,
    utility_coord: HexCoord = null
) -> StringName:
    selected_id = 0
    selected_coord = coord
    if worker_id > 0:
        selected_kind = &"worker"
        selected_id = worker_id
    elif building_id > 0:
        selected_kind = &"building"
        selected_id = building_id
    elif utility_coord != null:
        selected_kind = &"utility_segment"
        selected_coord = utility_coord
    elif link_id > 0:
        selected_kind = &"link"
        selected_id = link_id
    elif coord != null:
        selected_kind = &"hex"
    else:
        selected_kind = &""
    selection_changed.emit(selected_kind, selected_id, selected_coord)
    return selected_kind
