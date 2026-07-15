extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    _assert_quota_and_source_slots()
    _assert_priority_and_aging()
    _assert_assignment_stability_and_release()
    return finish()


func _assert_quota_and_source_slots() -> void:
    var state := _state_with_two_links(3)
    var invalid := CommandSystem.new().apply(
        state,
        LinkSettingsCommand.new(1, 1, 1, 2, 2, true)
    )
    assert_eq(invalid.code, &"source_slots_exceeded", "сумма квот не превышает места источника")
    LogisticsGraphTestFactory.add_building(state, 8, &"main_warehouse", HexCoord.new(7, 0))
    assert_eq(
        CommandSystem.new().apply(state, LinkCommand.create(1, 2, 1, 8, WOOD)).code,
        &"source_slots_exceeded",
        "новая ручная линия тоже соблюдает суммарный лимит source"
    )

    WorkforceSystem.new().run(state, 1)
    assert_true(_workers_on_link(state, 1) <= 1, "линия не получает больше квоты")
    assert_true(_workers_on_link(state, 2) <= 1, "вторая линия не получает больше квоты")
    assert_true(_workers_on_source(state, 1) <= 2, "источник L1 использует не более двух workers")

    var second_source := LogisticsGraphTestFactory.add_building(
        state,
        7,
        &"wood_source",
        HexCoord.new(0, 2)
    )
    second_source.add_amount(WOOD, 4)
    state.logistics_links[3] = LogisticsLinkState.new(3, 7, 2, WOOD, false, 2, 2)
    state.next_link_id = 4
    WorkforceSystem.new().run(state, 2)
    assert_true(_workers_on_source(state, 1) <= 2, "первый L1 source ограничен двумя")
    assert_true(_workers_on_source(state, 7) <= 2, "второй L1 source ограничен двумя")


func _assert_priority_and_aging() -> void:
    var state := _state_with_two_links(1)
    (state.logistics_links[1] as LogisticsLinkState).priority = 2
    (state.logistics_links[2] as LogisticsLinkState).priority = 0
    var first_link := 0
    var low_was_served := false
    for tick in range(1, 40):
        WorkforceSystem.new().run(state, tick)
        var worker := state.get_worker(4)
        if tick == 1:
            first_link = worker.link_id
        if worker.link_id == 2:
            low_was_served = true
        worker.link_id = 0
    assert_eq(first_link, 1, "высокий приоритет выигрывает начальный дефицит")
    assert_true(low_was_served, "aging не допускает постоянного голодания низкого приоритета")

    var reserved := _state_with_two_links(1)
    reserved.get_building(1).inventories[WOOD] = 1
    WorkforceSystem.new().run(reserved, 1)
    var reserved_worker := reserved.get_worker(4)
    reserved.get_building(1).reserve_outgoing(WOOD, 1)
    reserved_worker.action = WorkerState.TO_SOURCE
    for tick in range(2, 30):
        WorkforceSystem.new().run(reserved, tick)
    reserved.get_building(1).release_outgoing(WOOD, 1)
    reserved_worker.action = WorkerState.IDLE
    reserved_worker.link_id = 0
    WorkforceSystem.new().run(reserved, 30)
    assert_eq(
        reserved_worker.link_id,
        2,
        "ожидающая линия стареет, пока груз зарезервирован конкурентом"
    )


func _assert_assignment_stability_and_release() -> void:
    var state := _state_with_two_links(1)
    var worker := state.get_worker(4)
    worker.link_id = 1
    worker.cargo_resource_id = WOOD
    worker.action = WorkerState.TO_DESTINATION
    assert_eq(
        CommandSystem.new().apply(
            state,
            LinkSettingsCommand.new(1, 30, 1, 0, 2, true)
        ).code,
        &"link_quota_in_use",
        "quota не уменьшается ниже активного cargo worker"
    )
    WorkforceSystem.new().run(state, 1)
    assert_eq(worker.link_id, 1, "worker с грузом не переназначается")

    worker.cargo_resource_id = &""
    worker.action = WorkerState.IDLE
    state.get_building(1).inventories.clear()
    WorkforceSystem.new().run(state, 2)
    assert_eq(worker.link_id, 0, "место освобождается после рейса без доступной работы")


func _state_with_two_links(worker_count: int) -> SimulationState:
    var state := LogisticsGraphTestFactory.basic()
    state.logistics_topology_dirty = false
    state.logistics_links = {
        1: LogisticsLinkState.new(1, 1, 2, WOOD, false, 1, 2),
        2: LogisticsLinkState.new(2, 1, 3, WOOD, false, 1, 0),
    }
    state.next_link_id = 3
    state.get_building(1).add_amount(WOOD, 8)
    var coords := [HexCoord.new(1, 2), HexCoord.new(2, 2), HexCoord.new(4, 2)]
    for index in worker_count:
        var worker_id := 4 + index
        var worker := WorkerState.new(worker_id, coords[index])
        state.workers[worker_id] = worker
        state.worker_occupancy[worker.coord.key()] = worker_id
    state.next_entity_id = 4 + worker_count
    return state


func _workers_on_link(state: SimulationState, link_id: int) -> int:
    var count := 0
    for value: Variant in state.workers.values():
        if (value as WorkerState).link_id == link_id:
            count += 1
    return count


func _workers_on_source(state: SimulationState, source_id: int) -> int:
    var count := 0
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        var link := state.logistics_links.get(worker.link_id) as LogisticsLinkState
        if link != null and link.source_id == source_id:
            count += 1
    return count
