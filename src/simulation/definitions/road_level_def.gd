class_name RoadLevelDef
extends Resource

const LEVEL_OPEN_GROUND := 0
const LEVEL_PATH := 1
const LEVEL_DIRT_ROAD := 2

@export_range(LEVEL_OPEN_GROUND, LEVEL_DIRT_ROAD) var level: int = LEVEL_OPEN_GROUND
@export_range(1, 100000) var traversal_ticks: int = 4
@export_range(0, 100000) var upgrade_cost: int = 0
