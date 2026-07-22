extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    _assert_loader_converts_flows()
    _assert_compatibility_duplicates_and_cycles()
    _assert_dispatch_stop()
    _assert_path_cost_cache_tracks_routing_topology()
    _assert_removal_releases_idle_workers()
    _assert_removal_finishes_active_cargo()
    return finish()


func _assert_loader_converts_flows() -> void:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    assert_eq(state.delivery_flows, [], "delivery_flows остаются только входным форматом")
    assert_eq(state.logistics_links.size(), 2, "начальные flows конвертируются в связи")
    assert_eq(state.next_link_id, 3, "следующий ID связи стабилен")


func _assert_compatibility_duplicates_and_cycles() -> void:
    var state := LogisticsGraphTestFactory.basic()
    var commands := CommandSystem.new()
    var source_to_depot := commands.apply(state, LinkCommand.create(1, 1, 1, 3, WOOD))
    assert_true(source_to_depot.accepted, "источник должен связываться со складом")
    assert_eq(
        commands.apply(state, LinkCommand.create(1, 2, 1, 3, WOOD)).code,
        &"duplicate_link",
        "дубликат связи должен отклоняться"
    )
    assert_eq(
        commands.apply(
            state,
            LinkCommand.create(
                1,
                3,
                1,
                LogisticsGraphTestFactory.add_building(
                    state,
                    4,
                    &"wood_source",
                    HexCoord.new(0, 2)
                ).id,
                WOOD
            )
        ).code,
        &"incompatible_link",
        "источник не должен связываться с источником"
    )
    assert_true(
        commands.apply(state, LinkCommand.create(1, 4, 3, 2, WOOD)).accepted,
        "перевалочный склад должен связываться с главным"
    )
    assert_eq(
        commands.apply(state, LinkCommand.create(1, 5, 2, 3, WOOD)).code,
        &"link_cycle",
        "обратное ребро должно отклоняться как цикл"
    )


func _assert_dispatch_stop() -> void:
    var state := LogisticsGraphTestFactory.basic(false)
    state.get_building(1).add_amount(WOOD, 1)
    state.logistics_links[1] = LogisticsLinkState.new(1, 1, 2, WOOD, false, 1, 2)
    state.next_link_id = 2
    var result := CommandSystem.new().apply(state, LinkSettingsCommand.new(1, 10, 1, 1, 2, false))
    assert_true(result.accepted, "остановка отгрузки должна применяться")
    JobSystem.new().run(state, 1)
    assert_eq(state.jobs.size(), 0, "остановленная связь не создаёт jobs")


func _assert_path_cost_cache_tracks_routing_topology() -> void:
    var scenario := load("res://data/scenarios/full_industrial.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var system := LogisticsLinkSystem.new()
    var pathfinder := Pathfinder.new()
    system.run(state, pathfinder)
    var initial_searches: int = system.get_path_cost_evaluation_count()
    assert_true(initial_searches > 0, "первичная топология вычисляет стоимость авторских маршрутов")

    state.logistics_topology_dirty = true
    system.run(state, pathfinder)
    assert_eq(
        system.get_path_cost_evaluation_count(),
        initial_searches,
        "неизменившаяся карта повторно использует стоимость маршрутов"
    )

    state.map_state.get_cell(HexCoord.new(6, 6)).road_level = RoadLevelDef.LEVEL_PATH
    state.logistics_topology_dirty = true
    system.run(state, pathfinder)
    assert_true(
        system.get_path_cost_evaluation_count() > initial_searches,
        "изменение дороги инвалидирует производный кэш стоимости"
    )


func _assert_removal_releases_idle_workers() -> void:
    var state := LogisticsGraphTestFactory.basic(false)
    var link := LogisticsLinkState.new(1, 1, 2, WOOD, false, 1, 2)
    state.logistics_links[link.id] = link
    state.next_link_id = 2
    var worker := WorkerState.new(3, HexCoord.new(1, 0))
    worker.link_id = link.id
    state.workers[worker.id] = worker
    state.next_entity_id = 4

    var removed := LogisticsLinkSystem.new().remove_link(state, link.id, &"test")
    assert_true(removed.accepted, "удаление связи принимается")
    assert_true(not state.logistics_links.has(link.id), "связь без груза удаляется сразу")
    assert_eq(worker.link_id, 0, "удаление связи освобождает безопасно простаивающего работника")
    assert_true(
        not InvariantChecker.new().check(state).has(&"worker_link_mismatch"),
        "после удаления не остаётся dangling worker.link_id"
    )


func _assert_removal_finishes_active_cargo() -> void:
    var state := LogisticsGraphTestFactory.basic(false)
    var source := state.get_building(1)
    var destination := state.get_building(2)
    source.add_amount(WOOD, 1)
    destination.reserve_incoming(WOOD, 1)
    var link := LogisticsLinkState.new(1, 1, 2, WOOD, false, 1, 2)
    state.logistics_links[1] = link
    state.next_link_id = 2
    var job := DeliveryJob.new(1, 1, 2, WOOD, 2, 1)
    job.link_id = 1
    job.worker_id = 4
    job.state = DeliveryJob.TO_DESTINATION
    state.jobs[1] = job
    state.next_job_id = 2
    var worker := WorkerState.new(4, HexCoord.new(4, 0))
    worker.job_id = 1
    worker.link_id = 1
    worker.cargo_resource_id = WOOD
    worker.action = WorkerState.TO_DESTINATION
    state.workers[4] = worker
    state.next_entity_id = 5

    var removed := CommandSystem.new().apply(state, LinkCommand.remove(1, 20, 1))
    assert_true(removed.accepted, "удаление активной связи должно приниматься")
    assert_true(state.logistics_links.has(1), "связь с грузом остаётся до завершения рейса")
    assert_true(link.is_closing, "активная связь переходит в closing")
    assert_true(not link.dispatch_enabled, "closing-связь не создаёт новые jobs")
    assert_true(state.jobs.has(1), "активный груз не уничтожается")
    assert_eq(worker.cargo_resource_id, WOOD, "груз не телепортируется и не исчезает")

    state.jobs.erase(1)
    worker.job_id = 0
    worker.link_id = 0
    worker.cargo_resource_id = &""
    worker.action = WorkerState.IDLE
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    assert_true(not state.logistics_links.has(1), "closing-связь удаляется после последнего рейса")
