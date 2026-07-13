class_name ScenarioDef
extends Resource

@export_range(1, 512) var width: int = 18
@export_range(1, 512) var height: int = 18
@export var seed: int = 1
@export var catalog: DefinitionCatalog
@export var initial_buildings: Array[InitialBuildingDef] = []
