class_name SimulationState
extends RefCounted

var tick: int = 0
var revision: int = 0
var seed: int
var map_state: HexMapState
var catalog: DefinitionCatalog
var buildings: Dictionary = {}
var occupied_cells: Dictionary = {}
var main_warehouse_id: int = 0
var next_entity_id: int = 1
var last_events: Array[StringName] = []
var events: Array[SimulationEvent] = []
var workers: Dictionary = {}
var jobs: Dictionary = {}
var delivery_flows: Array[DeliveryFlowState] = []
var logistics_links: Dictionary = {}
var next_link_id: int = 1
var logistics_topology_dirty: bool = false
var worker_occupancy: Dictionary = {}
var cell_reservations: Dictionary = {}
var next_job_id: int = 1
var generated_totals: Dictionary = {}
var delivered_totals: Dictionary = {}
var consumed_totals: Dictionary = {}
var worker_ticks_per_hex: int = 4
var load_ticks: int = 2
var unload_ticks: int = 2
var repath_after_ticks: int = 10
var telemetry: Dictionary = {}
var telemetry_window := TelemetryWindow.new()
var diagnostic_report := DiagnosticReport.new()
var production_states: Dictionary = {}


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


func get_worker(entity_id: int) -> WorkerState:
    return workers.get(entity_id) as WorkerState


func get_job(job_id: int) -> DeliveryJob:
    return jobs.get(job_id) as DeliveryJob
