class_name LogisticsPortDef
extends Resource

const DIRECTION_INPUT := &"input"
const DIRECTION_OUTPUT := &"output"

const ROLE_SOURCE := &"source"
const ROLE_STORAGE := &"storage"
const ROLE_MAIN_WAREHOUSE := &"main_warehouse"
const ROLE_TRANSFER_DEPOT := &"transfer_depot"
const ROLE_PRODUCTION := &"production"

@export var direction: StringName = DIRECTION_INPUT
@export var resource_id: StringName
@export var accepted_building_roles: Array[StringName] = []
