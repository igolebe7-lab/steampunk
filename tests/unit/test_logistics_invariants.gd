extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var ids: Array = state.workers.keys()
    ids.sort()
    state.get_worker(ids[1]).coord = state.get_worker(ids[0]).coord
    assert_true(InvariantChecker.new().check(state).has(&"worker_overlap"), "overlap обнаруживается")

    var clean := ScenarioLoader.new().load_scenario(scenario).state
    clean.generated_totals[&"wood"] = 1
    assert_true(
        InvariantChecker.new().check(clean).has(&"resource_conservation"),
        "потеря груза обнаруживается"
    )

    var missing_reservation := _state_with_jobs()
    var reserved_job := missing_reservation.get_job(1)
    missing_reservation.get_building(reserved_job.source_id).outgoing_reserved.clear()
    assert_true(
        InvariantChecker.new().check(missing_reservation).has(&"reservation_ledger_mismatch"),
        "активный job без исходящего резерва обнаруживается"
    )

    var mismatched_state := _state_with_jobs()
    AssignmentSystem.new().run(mismatched_state, Pathfinder.new(), 10)
    var assigned_job := mismatched_state.get_job(1)
    mismatched_state.get_worker(assigned_job.worker_id).action = WorkerState.TO_SOURCE
    assert_true(
        InvariantChecker.new().check(mismatched_state).has(&"worker_job_state_mismatch"),
        "несогласованные worker action и job state обнаруживаются"
    )

    var missing_cell_reservation := ScenarioLoader.new().load_scenario(scenario).state
    var worker_ids: Array = missing_cell_reservation.workers.keys()
    worker_ids.sort()
    var moving_worker := missing_cell_reservation.get_worker(worker_ids[0])
    var target := moving_worker.coord.neighbor(0)
    moving_worker.route = [moving_worker.coord, target]
    moving_worker.segment_target = target
    moving_worker.segment_duration = 4
    assert_true(
        InvariantChecker.new().check(missing_cell_reservation).has(&"invalid_cell_reservation"),
        "segment target без reservation обнаруживается"
    )

    var duplicate_depot := ScenarioLoader.new().load_scenario(scenario).state
    var definition := duplicate_depot.catalog.get_building(&"transfer_depot")
    var first := BuildingState.new(duplicate_depot.next_entity_id, definition.id, HexCoord.new(1, 1), 2)
    first.inventory_capacity = definition.inventory_capacity
    duplicate_depot.buildings[first.id] = first
    duplicate_depot.occupied_cells[first.coord.key()] = first.id
    duplicate_depot.next_entity_id += 1
    var second := BuildingState.new(duplicate_depot.next_entity_id, definition.id, HexCoord.new(2, 1), 2)
    second.inventory_capacity = definition.inventory_capacity
    duplicate_depot.buildings[second.id] = second
    duplicate_depot.occupied_cells[second.coord.key()] = second.id
    duplicate_depot.next_entity_id += 1
    assert_true(
        InvariantChecker.new().check(duplicate_depot).has(&"multiple_transfer_depots"),
        "инвариант запрещает более одного перевалочного склада"
    )
    return finish()


func _state_with_jobs() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    WorkforceSystem.new().run(state, 10)
    JobSystem.new().run(state, 10)
    return state
