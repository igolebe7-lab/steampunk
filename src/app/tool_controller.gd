class_name ToolController
extends RefCounted

const INSPECT := &"inspect"
const ROAD := &"road"
const DEPOT := &"depot"
const LINK_ORIGIN := &"link_origin"
const LINK_DESTINATION := &"link_destination"
const PIPE_BUILD := &"pipe_build"
const PIPE_REMOVE := &"pipe_remove"

var mode: StringName = INSPECT
var link_origin_id: int = 0
var pipe_coords: Array[HexCoord] = []


func begin_road() -> void:
    mode = ROAD
    link_origin_id = 0


func begin_depot() -> void:
    mode = DEPOT
    link_origin_id = 0


func begin_link() -> void:
    mode = LINK_ORIGIN
    link_origin_id = 0


func begin_pipe_build() -> void:
    mode = PIPE_BUILD
    link_origin_id = 0
    pipe_coords.clear()


func begin_pipe_remove() -> void:
    mode = PIPE_REMOVE
    link_origin_id = 0
    pipe_coords.clear()


func finish_pipe() -> Dictionary:
    if not mode in [PIPE_BUILD, PIPE_REMOVE] or pipe_coords.is_empty():
        return {&"code": &"ignored"}
    var result := {
        &"code": mode,
        &"cells": pipe_coords.duplicate(),
    }
    cancel()
    return result


func cancel() -> void:
    mode = INSPECT
    link_origin_id = 0
    pipe_coords.clear()


func handle_selection(kind: StringName, entity_id: int, coord: HexCoord) -> Dictionary:
    if mode in [PIPE_BUILD, PIPE_REMOVE] and kind in [&"hex", &"utility_segment"] and coord != null:
        if pipe_coords.has(coord):
            return {&"code": &"ignored"}
        if not pipe_coords.is_empty() and pipe_coords[-1].distance_to(coord) != 1:
            return {&"code": &"ignored"}
        pipe_coords.append(HexCoord.new(coord.q, coord.r))
        return {
            &"code": &"pipe_preview",
            &"operation": mode,
            &"cells": pipe_coords.duplicate(),
            &"cost": ceili(float(pipe_coords.size()) / 2.0),
        }
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
