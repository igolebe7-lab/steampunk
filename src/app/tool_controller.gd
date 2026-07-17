class_name ToolController
extends RefCounted

signal mode_changed(mode: StringName)

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
    _set_mode(ROAD)
    link_origin_id = 0


func begin_depot() -> void:
    _set_mode(DEPOT)
    link_origin_id = 0


func begin_link() -> void:
    _set_mode(LINK_ORIGIN)
    link_origin_id = 0


func begin_pipe_build() -> void:
    _set_mode(PIPE_BUILD)
    link_origin_id = 0
    pipe_coords.clear()


func begin_pipe_remove() -> void:
    _set_mode(PIPE_REMOVE)
    link_origin_id = 0
    pipe_coords.clear()


func prepare_pipe_intent() -> Dictionary:
    if not mode in [PIPE_BUILD, PIPE_REMOVE] or pipe_coords.is_empty():
        return {&"code": &"ignored"}
    return {
        &"code": mode,
        &"cells": pipe_coords.duplicate(),
    }


func resolve_pipe_result(accepted: bool) -> void:
    if accepted and mode in [PIPE_BUILD, PIPE_REMOVE]:
        cancel()


func cancel() -> void:
    _set_mode(INSPECT)
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
        _set_mode(LINK_DESTINATION)
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


func _set_mode(value: StringName) -> void:
    if mode == value:
        return
    mode = value
    mode_changed.emit(mode)
