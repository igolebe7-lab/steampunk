extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    _assert_scenario_starts_with_main_warehouse()
    _assert_place_depot_costs_wood_and_uses_stable_id()
    _assert_place_requires_a_valid_roadside_cell()
    _assert_only_one_transfer_depot_is_allowed()
    _assert_demolish_requires_an_idle_empty_depot()
    _assert_demolish_removes_idle_links_atomically()
    _assert_demolish_rejects_active_cargo_atomically()
    _assert_failed_refund_preserves_links()
    _assert_demolish_refunds_and_releases_occupancy()
    return finish()


func _assert_scenario_starts_with_main_warehouse() -> void:
    var state := _loaded_state()
    assert_true(state.main_warehouse_id > 0, "сценарий должен назначать главный склад")
    var warehouse := state.get_building(state.main_warehouse_id)
    assert_true(warehouse != null, "главный склад должен существовать")
    if warehouse != null:
        assert_eq(warehouse.definition_id, &"main_warehouse", "центральный объект — main_warehouse")
        assert_eq(warehouse.inventory_capacity, 100, "главный склад вмещает 100 древесины")


func _assert_place_depot_costs_wood_and_uses_stable_id() -> void:
    var state := _placeable_state(20)
    var coord := _place_coord(state)
    var expected_id := state.next_entity_id
    var result := CommandSystem.new().apply(state, DepotCommand.place(1, 10, coord))

    assert_true(result.accepted, "склад должен размещаться на валидной клетке")
    assert_eq(result.parameters.get(&"building_id"), expected_id, "результат сообщает стабильный entity id")
    assert_eq(result.parameters.get(&"cost"), 10, "размещение стоит 10 древесины")
    assert_eq(state.next_entity_id, expected_id + 1, "entity id не переиспользуется")
    var depot := state.get_building(expected_id)
    assert_true(depot != null, "размещённый склад должен появиться в состоянии")
    if depot != null:
        assert_eq(depot.definition_id, &"transfer_depot", "создаётся transfer_depot")
        assert_eq(depot.inventory_capacity, 40, "перевалочный склад вмещает 40")
        var definition := state.catalog.get_building(depot.definition_id)
        assert_eq(definition.outgoing_worker_slots(depot.level), 2, "склад первого уровня имеет 2 места")
    assert_eq(state.occupied_cells.get(coord.key()), expected_id, "клетка должна стать занятой")
    assert_eq(_main_warehouse(state).get_amount(WOOD), 10, "стоимость списывается из главного склада")


func _assert_place_requires_a_valid_roadside_cell() -> void:
    var missing_road := _placeable_state(20, false)
    var coord := _place_coord(missing_road)
    _assert_place_rejected_unchanged(missing_road, coord, &"depot_not_adjacent_to_road")

    var occupied := _placeable_state(20)
    coord = _place_coord(occupied)
    occupied.occupied_cells[coord.key()] = occupied.main_warehouse_id
    _assert_place_rejected_unchanged(occupied, coord, &"cell_occupied")

    var blocked := _placeable_state(20)
    coord = _place_coord(blocked)
    blocked.map_state.get_cell(coord).traversable = false
    _assert_place_rejected_unchanged(blocked, coord, &"cell_not_traversable")

    var missing := _placeable_state(20)
    _assert_place_rejected_unchanged(missing, HexCoord.new(99, 99), &"cell_missing")

    var poor := _placeable_state(9)
    _assert_place_rejected_unchanged(poor, _place_coord(poor), &"insufficient_wood")


func _assert_only_one_transfer_depot_is_allowed() -> void:
    var state := _placeable_state(30)
    var system := CommandSystem.new()
    var first_coord := _place_coord(state)
    assert_true(system.apply(state, DepotCommand.place(1, 20, first_coord)).accepted, "первый склад размещается")

    var second_coord := HexCoord.new(7, 3)
    state.map_state.get_cell(second_coord.neighbor(0)).road_level = RoadLevelDef.LEVEL_PATH
    var result := system.apply(state, DepotCommand.place(2, 21, second_coord))
    assert_eq(result.code, &"transfer_depot_exists", "второй перевалочный склад запрещён")
    assert_eq(_main_warehouse(state).get_amount(WOOD), 20, "отказ не списывает древесину")
    assert_true(not state.occupied_cells.has(second_coord.key()), "отказ не занимает вторую клетку")


func _assert_demolish_requires_an_idle_empty_depot() -> void:
    var inventory_state := _state_with_depot()
    var inventory_depot := _transfer_depot(inventory_state)
    inventory_depot.add_amount(WOOD, 1)
    _assert_demolish_rejected(inventory_state, inventory_depot.id, &"depot_not_empty")

    var reservation_state := _state_with_depot()
    var reservation_depot := _transfer_depot(reservation_state)
    reservation_depot.incoming_reserved[WOOD] = 1
    _assert_demolish_rejected(reservation_state, reservation_depot.id, &"depot_has_reservations")
    assert_eq(reservation_depot.get_incoming_reserved(WOOD), 1, "отказ сохраняет reservation ledger")

    var job_state := _state_with_depot()
    var job_depot := _transfer_depot(job_state)
    job_state.jobs[1] = DeliveryJob.new(1, job_state.main_warehouse_id, job_depot.id, WOOD, 2, 0)
    _assert_demolish_rejected(job_state, job_depot.id, &"depot_has_active_jobs")
    assert_true(job_state.jobs.has(1), "отказ сохраняет active job")


func _assert_demolish_removes_idle_links_atomically() -> void:
    var state := _state_with_depot()
    var depot := _transfer_depot(state)
    var link := LogisticsLinkState.new(1, depot.id, state.main_warehouse_id, WOOD, false, 1, 2)
    state.logistics_links[link.id] = link
    state.next_link_id = 2
    var worker := WorkerState.new(state.next_entity_id, HexCoord.new(1, 0))
    worker.link_id = link.id
    state.workers[worker.id] = worker
    state.worker_occupancy[worker.coord.key()] = worker.id
    state.next_entity_id += 1

    var result := CommandSystem.new().apply(state, DepotCommand.demolish(2, 51, depot.id))
    assert_true(result.accepted, "связанный только idle-связями склад разбирается атомарно")
    assert_true(not state.logistics_links.has(link.id), "idle-связь удаляется до здания")
    assert_eq(worker.link_id, 0, "idle worker отвязывается при атомарном демонтаже")
    assert_eq(state.get_building(depot.id), null, "здание удаляется после безопасных связей")


func _assert_demolish_rejects_active_cargo_atomically() -> void:
    var state := _state_with_depot()
    var depot := _transfer_depot(state)
    var link := LogisticsLinkState.new(1, depot.id, state.main_warehouse_id, WOOD, false, 1, 2)
    state.logistics_links[link.id] = link
    state.next_link_id = 2
    var worker := WorkerState.new(state.next_entity_id, HexCoord.new(1, 0))
    worker.link_id = link.id
    worker.cargo_resource_id = WOOD
    worker.action = WorkerState.TO_DESTINATION
    state.workers[worker.id] = worker
    state.worker_occupancy[worker.coord.key()] = worker.id
    state.next_entity_id += 1
    var initial_wood := _main_warehouse(state).get_amount(WOOD)

    var result := CommandSystem.new().apply(state, DepotCommand.demolish(2, 52, depot.id))
    assert_eq(result.code, &"depot_has_active_cargo", "активный груз запрещает демонтаж")
    assert_true(state.get_building(depot.id) != null, "отказ с грузом сохраняет склад")
    assert_true(state.logistics_links.has(link.id), "отказ с грузом сохраняет связь")
    assert_eq(worker.link_id, link.id, "отказ с грузом сохраняет worker binding")
    assert_eq(worker.cargo_resource_id, WOOD, "отказ с грузом сохраняет груз")
    assert_eq(_main_warehouse(state).get_amount(WOOD), initial_wood, "отказ с грузом не возвращает дерево")


func _assert_failed_refund_preserves_links() -> void:
    var state := _state_with_depot()
    var depot := _transfer_depot(state)
    var link := LogisticsLinkState.new(1, depot.id, state.main_warehouse_id, WOOD, false, 1, 2)
    state.logistics_links[link.id] = link
    state.next_link_id = 2
    var main := _main_warehouse(state)
    assert_true(main.add_amount(WOOD, main.free_capacity()), "тест заполняет главный склад")

    var result := CommandSystem.new().apply(state, DepotCommand.demolish(2, 53, depot.id))
    assert_eq(result.code, &"main_warehouse_full", "невозможный refund отклоняется до мутаций")
    assert_true(state.get_building(depot.id) != null, "ошибка refund сохраняет депо")
    assert_true(state.logistics_links.has(link.id), "ошибка refund сохраняет связь")


func _assert_demolish_refunds_and_releases_occupancy() -> void:
    var state := _state_with_depot()
    var depot := _transfer_depot(state)
    var depot_id := depot.id
    var coord_key := depot.coord.key()
    var next_id := state.next_entity_id
    var initial_wood := _main_warehouse(state).get_amount(WOOD)
    depot.incoming_reserved[WOOD] = 0
    depot.outgoing_reserved[WOOD] = 0

    var result := CommandSystem.new().apply(state, DepotCommand.demolish(2, 30, depot_id))
    assert_true(result.accepted, "пустой склад с нулевыми ledger-записями должен разбираться")
    assert_eq(result.parameters.get(&"refund"), 5, "результат сообщает возврат 5 древесины")
    assert_eq(state.get_building(depot_id), null, "разобранный склад удаляется")
    assert_true(not state.occupied_cells.has(coord_key), "занятая клетка освобождается")
    assert_eq(_main_warehouse(state).get_amount(WOOD), initial_wood + 5, "главный склад получает 5 древесины")
    assert_eq(state.next_entity_id, next_id, "разбор не откатывает генератор entity id")


func _assert_place_rejected_unchanged(
    state: SimulationState,
    coord: HexCoord,
    expected_code: StringName
) -> void:
    var initial_buildings := state.buildings.size()
    var initial_next_id := state.next_entity_id
    var initial_wood := _main_warehouse(state).get_amount(WOOD)
    var result := CommandSystem.new().apply(state, DepotCommand.place(1, 40, coord))
    assert_eq(result.code, expected_code, "невалидное размещение возвращает ожидаемый код")
    assert_eq(state.buildings.size(), initial_buildings, "отказ не создаёт здание")
    assert_eq(state.next_entity_id, initial_next_id, "отказ не расходует entity id")
    assert_eq(_main_warehouse(state).get_amount(WOOD), initial_wood, "отказ не списывает древесину")


func _assert_demolish_rejected(
    state: SimulationState,
    depot_id: int,
    expected_code: StringName
) -> void:
    var depot := state.get_building(depot_id)
    var coord_key := depot.coord.key()
    var initial_wood := _main_warehouse(state).get_amount(WOOD)
    var result := CommandSystem.new().apply(state, DepotCommand.demolish(2, 50, depot_id))
    assert_eq(result.code, expected_code, "небезопасный разбор возвращает ожидаемый код")
    assert_true(state.get_building(depot_id) != null, "отказ не удаляет склад")
    assert_eq(state.occupied_cells.get(coord_key), depot_id, "отказ сохраняет occupancy")
    assert_eq(_main_warehouse(state).get_amount(WOOD), initial_wood, "отказ не возвращает древесину")


func _state_with_depot() -> SimulationState:
    var state := _placeable_state(30)
    var definition := state.catalog.get_building(&"transfer_depot")
    var coord := _place_coord(state)
    var depot := BuildingState.new(state.next_entity_id, definition.id, coord, 2)
    depot.inventory_capacity = definition.inventory_capacity
    state.buildings[depot.id] = depot
    state.occupied_cells[coord.key()] = depot.id
    state.next_entity_id += 1
    _main_warehouse(state).remove_amount(WOOD, 10)
    return state


func _placeable_state(wood: int, with_road: bool = true) -> SimulationState:
    var catalog := DefinitionCatalog.new()
    var warehouse_definition := BuildingDef.new()
    warehouse_definition.id = &"main_warehouse"
    warehouse_definition.display_name_key = &"building.main_warehouse.name"
    warehouse_definition.inventory_capacity = 100
    warehouse_definition.role = LogisticsPortDef.ROLE_MAIN_WAREHOUSE
    var depot_definition := BuildingDef.new()
    depot_definition.id = &"transfer_depot"
    depot_definition.display_name_key = &"building.transfer_depot.name"
    depot_definition.inventory_capacity = 40
    depot_definition.role = LogisticsPortDef.ROLE_TRANSFER_DEPOT
    depot_definition.outgoing_worker_slots_by_level = [2]
    catalog.buildings = [warehouse_definition, depot_definition]

    var map_state := HexMapState.new(18, 18)
    var warehouse_coord := HexCoord.new(9, 4)
    var warehouse := BuildingState.new(1, warehouse_definition.id, warehouse_coord, 2)
    warehouse.inventory_capacity = warehouse_definition.inventory_capacity
    var state := SimulationState.new(
        1,
        map_state,
        catalog,
        {1: warehouse},
        {warehouse_coord.key(): 1},
        2
    )
    state.main_warehouse_id = warehouse.id
    var payer := _main_warehouse(state)
    payer.add_amount(WOOD, wood)
    state.generated_totals[WOOD] = wood
    var coord := _place_coord(state)
    if with_road:
        state.map_state.get_cell(coord.neighbor(0)).road_level = RoadLevelDef.LEVEL_PATH
    return state


func _place_coord(state: SimulationState) -> HexCoord:
    return HexCoord.new(9, 3)


func _loaded_state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return ScenarioLoader.new().load_scenario(scenario).state


func _main_warehouse(state: SimulationState) -> BuildingState:
    return state.get_building(state.main_warehouse_id)


func _transfer_depot(state: SimulationState) -> BuildingState:
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        if building.definition_id == &"transfer_depot":
            return building
    return null
