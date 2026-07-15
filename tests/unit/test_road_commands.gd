extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    _assert_single_cell_upgrades_and_costs()
    _assert_batches_are_atomic()
    _assert_insufficient_wood_is_atomic()
    return finish()


func _assert_single_cell_upgrades_and_costs() -> void:
    var state := _road_state(10)
    var road_cell := state.map_state.get_cells()[1]
    var system := CommandSystem.new()

    var path_result := system.apply(
        state,
        BuildRoadCommand.new(1, 10, [road_cell.coord])
    )
    assert_true(path_result.accepted, "свободная земля должна улучшаться до тропы")
    assert_eq(road_cell.road_level, RoadLevelDef.LEVEL_PATH, "первое улучшение создаёт тропу")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(WOOD), 9, "тропа стоит 1 древесину")
    assert_eq(path_result.parameters.get(&"cost"), 1, "результат сообщает стоимость тропы")
    assert_eq(path_result.parameters.get(&"cell_count"), 1, "результат сообщает размер пакета")

    var road_result := system.apply(
        state,
        BuildRoadCommand.new(2, 20, [road_cell.coord])
    )
    assert_true(road_result.accepted, "тропа должна улучшаться до грунтовой дороги")
    assert_eq(road_cell.road_level, RoadLevelDef.LEVEL_DIRT_ROAD, "второе улучшение создаёт дорогу")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(WOOD), 7, "улучшение дороги стоит ещё 2 древесины")
    assert_eq(road_result.parameters.get(&"cost"), 2, "результат сообщает стоимость дороги")


func _assert_batches_are_atomic() -> void:
    var occupied := _road_state(20)
    _assert_rejected_batch_unchanged(
        occupied,
        [occupied.map_state.get_cells()[1].coord, occupied.map_state.get_cells()[0].coord],
        &"cell_occupied",
        "занятая клетка отклоняет весь пакет"
    )

    var missing := _road_state(20)
    _assert_rejected_batch_unchanged(
        missing,
        [missing.map_state.get_cells()[1].coord, HexCoord.new(99, 99)],
        &"cell_missing",
        "отсутствующая клетка отклоняет весь пакет"
    )

    var maximum := _road_state(20)
    maximum.map_state.get_cells()[2].road_level = RoadLevelDef.LEVEL_DIRT_ROAD
    _assert_rejected_batch_unchanged(
        maximum,
        [maximum.map_state.get_cells()[1].coord, maximum.map_state.get_cells()[2].coord],
        &"road_level_max",
        "максимальная дорога отклоняет весь пакет"
    )

    var blocked := _road_state(20)
    blocked.map_state.get_cells()[2].traversable = false
    _assert_rejected_batch_unchanged(
        blocked,
        [blocked.map_state.get_cells()[1].coord, blocked.map_state.get_cells()[2].coord],
        &"cell_not_traversable",
        "непроходимая клетка отклоняет весь пакет"
    )


func _assert_insufficient_wood_is_atomic() -> void:
    var state := _road_state(2)
    var first := state.map_state.get_cells()[1]
    var second := state.map_state.get_cells()[2]
    second.road_level = RoadLevelDef.LEVEL_PATH

    var result := CommandSystem.new().apply(
        state,
        BuildRoadCommand.new(1, 30, [first.coord, second.coord])
    )
    assert_eq(result.code, &"insufficient_wood", "нехватка древесины должна отклонять пакет")
    assert_eq(result.parameters.get(&"required"), 3, "отказ сообщает требуемую древесину")
    assert_eq(result.parameters.get(&"available"), 2, "отказ сообщает доступную древесину")
    assert_eq(first.road_level, RoadLevelDef.LEVEL_OPEN_GROUND, "первая клетка не меняется при отказе")
    assert_eq(second.road_level, RoadLevelDef.LEVEL_PATH, "вторая клетка не меняется при отказе")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(WOOD), 2, "оплата не списывается при отказе")


func _assert_rejected_batch_unchanged(
    state: SimulationState,
    coords: Array,
    expected_code: StringName,
    message: String
) -> void:
    var valid_cell := state.map_state.get_cell(coords[0] as HexCoord)
    var initial_level := valid_cell.road_level
    var initial_wood := state.get_building(state.main_warehouse_id).get_amount(WOOD)
    var result := CommandSystem.new().apply(state, BuildRoadCommand.new(1, 40, coords))
    assert_eq(result.code, expected_code, message)
    assert_eq(valid_cell.road_level, initial_level, "%s: валидная клетка не должна измениться" % message)
    assert_eq(
        state.get_building(state.main_warehouse_id).get_amount(WOOD),
        initial_wood,
        "%s: древесина не должна списаться" % message
    )


func _road_state(wood: int) -> SimulationState:
    var catalog := DefinitionCatalog.new()
    catalog.road_levels = [
        _road_level(RoadLevelDef.LEVEL_OPEN_GROUND, 4, 0),
        _road_level(RoadLevelDef.LEVEL_PATH, 3, 1),
        _road_level(RoadLevelDef.LEVEL_DIRT_ROAD, 2, 2),
    ]
    var map_state := HexMapState.new(4, 2)
    var warehouse_coord := map_state.get_cells()[0].coord
    var warehouse := BuildingState.new(1, &"main_warehouse", warehouse_coord, 2)
    warehouse.inventory_capacity = 100
    warehouse.add_amount(WOOD, wood)
    var state := SimulationState.new(
        1,
        map_state,
        catalog,
        {1: warehouse},
        {warehouse_coord.key(): 1},
        2
    )
    state.main_warehouse_id = 1
    return state


func _road_level(level: int, traversal_ticks: int, upgrade_cost: int) -> RoadLevelDef:
    var definition := RoadLevelDef.new()
    definition.level = level
    definition.traversal_ticks = traversal_ticks
    definition.upgrade_cost = upgrade_cost
    return definition
