class_name ScenarioDef
extends Resource

@export_range(1, 512) var width: int = 18
@export_range(1, 512) var height: int = 18
@export var seed: int = 1
@export var catalog: DefinitionCatalog
@export var initial_buildings: Array[InitialBuildingDef] = []
@export var initial_workers: Array[InitialWorkerDef] = []
@export var delivery_flows: Array[InitialDeliveryFlowDef] = []
@export_range(1, 100) var worker_ticks_per_hex: int = 4
@export_range(1, 100) var load_ticks: int = 2
@export_range(1, 100) var unload_ticks: int = 2
@export_range(1, 100) var repath_after_ticks: int = 10
