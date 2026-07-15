class_name LogisticsPipeline
extends RefCounted

var _source_system := SourceSystem.new()
var _logistics_link_system := LogisticsLinkSystem.new()
var _workforce_system := WorkforceSystem.new()
var _job_system := JobSystem.new()
var _assignment_system := AssignmentSystem.new()
var _path_system := PathSystem.new()
var _movement_system := MovementSystem.new()
var _inventory_system := InventorySystem.new()
var _production_system := ProductionSystem.new()
var _telemetry_system := TelemetrySystem.new()
var _diagnostics_system := DiagnosticsSystem.new()
var _pathfinder := Pathfinder.new()


func run(state: SimulationState, target_tick: int) -> void:
    _logistics_link_system.run(state, _pathfinder)
    _source_system.run(state, target_tick)
    _workforce_system.run(state, target_tick)
    _job_system.run(state, target_tick)
    _assignment_system.run(state, _pathfinder, target_tick)
    _path_system.run(state, _pathfinder, target_tick)
    _movement_system.run(state, _pathfinder, target_tick)
    _inventory_system.run(state, target_tick)
    _production_system.run(state, target_tick)
    _telemetry_system.run(state, target_tick)
    _diagnostics_system.run(state)


func reconcile_topology(state: SimulationState) -> void:
    _logistics_link_system.run(state, _pathfinder)
