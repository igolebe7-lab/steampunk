class_name ToolController
extends RefCounted

const INSPECT := &"inspect"
const ROAD := &"road"
const DEPOT := &"depot"
const LINK_ORIGIN := &"link_origin"
const LINK_DESTINATION := &"link_destination"

var mode: StringName = INSPECT
var link_origin_id: int = 0


func begin_road() -> void:
    mode = ROAD
    link_origin_id = 0


func begin_depot() -> void:
    mode = DEPOT
    link_origin_id = 0


func begin_link() -> void:
    mode = LINK_ORIGIN
    link_origin_id = 0


func cancel() -> void:
    mode = INSPECT
    link_origin_id = 0


func handle_selection(kind: StringName, entity_id: int, coord: HexCoord) -> Dictionary:
    if mode == ROAD and kind == &"hex" and coord != null:
        return {&"code": &"road_cell", &"coord": coord}
    if mode == DEPOT and kind == &"hex" and coord != null:
        return {&"code": &"depot_cell", &"coord": coord}
    if mode == LINK_ORIGIN and kind == &"building" and entity_id > 0:
        link_origin_id = entity_id
        mode = LINK_DESTINATION
        return {&"code": &"link_origin", &"source_id": entity_id}
    if (
        mode == LINK_DESTINATION
        and kind == &"building"
        and entity_id > 0
        and entity_id != link_origin_id
    ):
        var result := {
            &"code": &"link_complete",
            &"source_id": link_origin_id,
            &"destination_id": entity_id,
        }
        cancel()
        return result
    if mode == INSPECT:
        return {&"code": &"inspect", &"kind": kind, &"entity_id": entity_id, &"coord": coord}
    return {&"code": &"ignored"}
