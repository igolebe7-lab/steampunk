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
    var hit := peek_at_local_position(local_position)
    return resolve_hit(
        hit.get(&"worker_id", 0) as int,
        hit.get(&"building_id", 0) as int,
        hit.get(&"link_id", 0) as int,
        hit.get(&"coord") as HexCoord,
        hit.get(&"utility_coord") as HexCoord
    )


func peek_at_local_position(local_position: Vector2) -> Dictionary:
    if _state == null or _layout == null or _world == null:
        return {&"kind": &"", &"entity_id": 0, &"coord": null}
    var coord := _layout.pixel_to_coord(local_position)
    var worker_id := _world.hit_test_worker(local_position)
    var building_id := _world.hit_test_building(local_position)
    var utility_coord := _world.get_utility_network_view().hit_test_segment(local_position)
    var link_id := _world.get_diagnostics_view().hit_test_link(local_position)
    var map_coord: HexCoord = coord if _state.map_state.contains(coord) else null
    var resolved := _resolved_hit(worker_id, building_id, link_id, map_coord, utility_coord)
    resolved[&"worker_id"] = worker_id
    resolved[&"building_id"] = building_id
    resolved[&"link_id"] = link_id
    resolved[&"utility_coord"] = utility_coord
    return resolved


func resolve_hit(
    worker_id: int,
    building_id: int,
    link_id: int,
    coord: HexCoord,
    utility_coord: HexCoord = null
) -> StringName:
    var resolved := _resolved_hit(worker_id, building_id, link_id, coord, utility_coord)
    selected_kind = resolved[&"kind"] as StringName
    selected_id = resolved[&"entity_id"] as int
    selected_coord = resolved[&"coord"] as HexCoord
    selection_changed.emit(selected_kind, selected_id, selected_coord)
    return selected_kind


func _resolved_hit(
    worker_id: int,
    building_id: int,
    link_id: int,
    coord: HexCoord,
    utility_coord: HexCoord
) -> Dictionary:
    var kind: StringName = &""
    var entity_id := 0
    var resolved_coord := coord
    if worker_id > 0:
        kind = &"worker"
        entity_id = worker_id
    elif building_id > 0:
        kind = &"building"
        entity_id = building_id
    elif utility_coord != null:
        kind = &"utility_segment"
        resolved_coord = utility_coord
    elif link_id > 0:
        kind = &"link"
        entity_id = link_id
    elif coord != null:
        kind = &"hex"
    return {&"kind": kind, &"entity_id": entity_id, &"coord": resolved_coord}
