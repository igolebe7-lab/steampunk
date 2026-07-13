class_name DefinitionCatalog
extends Resource

@export var resources: Array[ResourceDef] = []
@export var buildings: Array[BuildingDef] = []


func validate() -> Array[StringName]:
    var errors: Array[StringName] = []
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
