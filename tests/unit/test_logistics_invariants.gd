extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var ids: Array = state.workers.keys()
    ids.sort()
    state.get_worker(ids[1]).coord = state.get_worker(ids[0]).coord
    assert_true(
        not InvariantChecker.new().check(state).has(&"worker_overlap"),
        "совпадающие клетки носильщиков допустимы"
    )

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
    _assert_telemetry_invariants(scenario)
    _assert_road_definitions_are_enforced(scenario)
    return finish()


func _assert_telemetry_invariants(scenario: ScenarioDef) -> void:
    var state := ScenarioLoader.new().load_scenario(scenario).state
    state.telemetry_window.append_sample({&"tick": 2})
    state.telemetry_window.append_sample({&"tick": 1})
    assert_true(
        InvariantChecker.new().check(state).has(&"invalid_telemetry_window"),
        "telemetry ticks должны быть строго возрастающими"
    )

    state = ScenarioLoader.new().load_scenario(scenario).state
    state.diagnostic_report = DiagnosticReport.new(&"free_text_reason", 1)
    assert_true(
        InvariantChecker.new().check(state).has(&"invalid_diagnostic_report"),
        "diagnostic report принимает только структурированные codes"
    )


func _assert_road_definitions_are_enforced(scenario: ScenarioDef) -> void:
    var invalid_level := ScenarioLoader.new().load_scenario(scenario).state
    invalid_level.map_state.get_cells()[0].road_level = RoadLevelDef.LEVEL_DIRT_ROAD + 1
    assert_true(
        InvariantChecker.new().check(invalid_level).has(&"invalid_road_level"),
        "road_level вне диапазона 0..2 нарушает инвариант"
    )

    var missing_definition := ScenarioLoader.new().load_scenario(scenario).state
    missing_definition.catalog.road_levels = missing_definition.catalog.road_levels.filter(
        func(definition: RoadLevelDef) -> bool:
            return definition.level != RoadLevelDef.LEVEL_OPEN_GROUND
    )
    assert_true(
        InvariantChecker.new().check(missing_definition).has(&"invalid_road_level"),
        "каждый road_level клетки должен иметь определение в каталоге"
    )


func _state_with_jobs() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    WorkforceSystem.new().run(state, 10)
    JobSystem.new().run(state, 10)
    return state
