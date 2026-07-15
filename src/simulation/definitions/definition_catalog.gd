class_name DefinitionCatalog
extends Resource

@export var resources: Array[ResourceDef] = []
@export var buildings: Array[BuildingDef] = []
@export var road_levels: Array[RoadLevelDef] = []


func validate() -> Array[StringName]:
    var errors: Array[StringName] = []
    var road_level_ids: Dictionary = {}
    for definition in road_levels:
        if (
            definition == null
            or definition.level < RoadLevelDef.LEVEL_OPEN_GROUND
            or definition.level > RoadLevelDef.LEVEL_DIRT_ROAD
            or definition.traversal_ticks <= 0
            or definition.upgrade_cost < 0
        ):
            errors.append(&"invalid_road_level")
        elif road_level_ids.has(definition.level):
            errors.append(&"duplicate_road_level")
        else:
            road_level_ids[definition.level] = true

    var resource_ids: Dictionary = {}
    for definition in resources:
        if definition == null or definition.id.is_empty() or definition.display_name_key.is_empty():
            errors.append(&"invalid_resource")
        elif resource_ids.has(definition.id):
            errors.append(&"duplicate_resource_id")
        else:
            resource_ids[definition.id] = true

    var building_ids: Dictionary = {}
    for definition in buildings:
        if (
            definition == null
            or definition.id.is_empty()
            or definition.display_name_key.is_empty()
            or definition.footprint.is_empty()
            or definition.inventory_capacity < 0
        ):
            errors.append(&"invalid_building")
        elif building_ids.has(definition.id):
            errors.append(&"duplicate_building_id")
        else:
            building_ids[definition.id] = true
            var footprint_cells: Dictionary = {}
            for offset in definition.footprint:
                if footprint_cells.has(offset):
                    errors.append(&"duplicate_footprint_cell")
                    break
                footprint_cells[offset] = true
            if definition.is_source():
                if get_resource(definition.source_resource_id) == null:
                    errors.append(&"unknown_source_resource")
                if definition.source_interval_ticks <= 0 or definition.source_capacity <= 0:
                    errors.append(&"invalid_source_config")
            elif definition.source_interval_ticks != 0 or definition.source_capacity != 0:
                errors.append(&"invalid_source_config")
    return errors


func get_resource(definition_id: StringName) -> ResourceDef:
    for definition in resources:
        if definition.id == definition_id:
            return definition
    return null


func get_building(definition_id: StringName) -> BuildingDef:
    for definition in buildings:
        if definition.id == definition_id:
            return definition
    return null


func get_road_level(level: int) -> RoadLevelDef:
    for definition in road_levels:
        if definition.level == level:
            return definition
    return null
