class_name SimulationState
extends RefCounted

var tick: int = 0
var seed: int
var map_state: HexMapState
var catalog: DefinitionCatalog
var buildings: Dictionary = {}
var occupied_cells: Dictionary = {}
var next_entity_id: int = 1
var last_events: Array[StringName] = []


func _init(
    p_seed: int,
    p_map_state: HexMapState,
    p_catalog: DefinitionCatalog,
    p_buildings: Dictionary,
    p_occupied_cells: Dictionary,
    p_next_entity_id: int
) -> void:
    seed = p_seed
    map_state = p_map_state
    catalog = p_catalog
    buildings = p_buildings
    occupied_cells = p_occupied_cells
    next_entity_id = p_next_entity_id


func get_building(entity_id: int) -> BuildingState:
    return buildings.get(entity_id) as BuildingState
