extends TestCase


func run() -> Array[String]:
    _assert_road_levels()
    _assert_building_management_definition()
    _assert_logistics_link_state()
    _assert_link_references_and_revision()
    return finish()


func _assert_road_levels() -> void:
    var catalog := DefinitionCatalog.new()
    catalog.road_levels = [
        _road_level(RoadLevelDef.LEVEL_DIRT_ROAD, 2, 2),
        _road_level(RoadLevelDef.LEVEL_OPEN_GROUND, 4, 0),
        _road_level(RoadLevelDef.LEVEL_PATH, 3, 1),
    ]

    assert_eq(catalog.validate(), [], "уровни дорог этапа 4 должны быть корректными")
    assert_eq(
        catalog.get_road_level(RoadLevelDef.LEVEL_OPEN_GROUND).traversal_ticks,
        4,
        "открытая земля проходится за четыре тика"
    )
    assert_eq(
        catalog.get_road_level(RoadLevelDef.LEVEL_PATH).traversal_ticks,
        3,
        "тропа проходится за три тика"
    )
    assert_eq(
        catalog.get_road_level(RoadLevelDef.LEVEL_DIRT_ROAD).traversal_ticks,
        2,
        "грунтовая дорога проходится за два тика"
    )


func _assert_building_management_definition() -> void:
    var output_port := LogisticsPortDef.new()
    output_port.direction = LogisticsPortDef.DIRECTION_OUTPUT
    output_port.resource_id = &"wood"
    output_port.accepted_building_roles = [
        LogisticsPortDef.ROLE_MAIN_WAREHOUSE,
        LogisticsPortDef.ROLE_TRANSFER_DEPOT,
    ]

    var definition := BuildingDef.new()
    definition.role = LogisticsPortDef.ROLE_SOURCE
    definition.max_level = 3
    definition.outgoing_worker_slots_by_level = [2, 3, 4]
    definition.logistics_ports = [output_port]
    definition.allows_direct_delivery_to_main = true

    assert_eq(definition.role, LogisticsPortDef.ROLE_SOURCE, "роль здания хранится в определении")
    assert_eq(definition.outgoing_worker_slots(1), 2, "источник первого уровня даёт два места")
    assert_eq(definition.outgoing_worker_slots(2), 3, "источник второго уровня даёт три места")
    assert_eq(definition.outgoing_worker_slots(3), 4, "источник третьего уровня даёт четыре места")
    assert_true(definition.allows_direct_delivery_to_main, "политика прямой доставки имеет data-default")

    var building := BuildingState.new(1, &"wood_source", HexCoord.new(), 2)
    assert_eq(building.level, 1, "здание создаётся на первом уровне")
    assert_true(building.allows_direct_delivery_to_main, "состояние хранит изменяемую политику доставки")


func _assert_logistics_link_state() -> void:
    var link := LogisticsLinkState.new(7, 11, 19, &"wood", true, 2, 3)

    assert_eq(link.id, 7, "идентификатор связи стабилен")
    assert_eq(link.source_id, 11, "отправитель связи стабилен")
    assert_eq(link.destination_id, 19, "получатель связи стабилен")
    assert_eq(link.resource_id, &"wood", "ресурс связи стабилен")
    assert_true(link.is_automatic, "тип автоматической связи сохраняется")
    assert_eq(link.quota, 2, "квота связи сохраняется")
    assert_eq(link.priority, 3, "приоритет связи сохраняется")


func _assert_link_references_and_revision() -> void:
    var worker := WorkerState.new(1, HexCoord.new())
    worker.link_id = 7
    assert_eq(worker.link_id, 7, "работник хранит обслуживаемую связь")

    var job := DeliveryJob.new(2, 11, 19, &"wood", 3, 5)
    job.link_id = 7
    assert_eq(job.link_id, 7, "заказ хранит связь")

    var state := SimulationState.new(1, HexMapState.new(1, 1), DefinitionCatalog.new(), {}, {}, 1)
    assert_eq(state.revision, 0, "ревизия нового состояния равна нулю")


func _road_level(level: int, traversal_ticks: int, upgrade_cost: int) -> RoadLevelDef:
    var definition := RoadLevelDef.new()
    definition.level = level
    definition.traversal_ticks = traversal_ticks
    definition.upgrade_cost = upgrade_cost
    return definition
