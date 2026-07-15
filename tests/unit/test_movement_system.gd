extends TestCase


func run() -> Array[String]:
    _assert_conflict_resolution_and_arrival()
    _assert_swap_is_rejected()
    _assert_repath_avoids_reserved_cell()
    _assert_repath_failure_is_explicit()
    return finish()


func _assert_conflict_resolution_and_arrival() -> void:
    var state := LogisticsTestFactory.two_workers_same_target()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_eq(state.cell_reservations.size(), 1, "клетка имеет одну reservation")
    assert_eq(state.cell_reservations.values()[0], 1, "при равном ожидании выигрывает меньший ID")
    assert_eq(state.get_worker(2).wait_reason, &"cell_reserved", "проигравший объясняет ожидание")
    for tick in range(2, 6):
        MovementSystem.new().run(state, Pathfinder.new(), tick)
    assert_eq(state.worker_occupancy.get(&"2:1", 0), 1, "занятость атомарно переходит в target")
    assert_true(not state.worker_occupancy.has(&"1:1"), "стартовая клетка освобождается после прибытия")
    assert_true(not state.cell_reservations.has(&"2:1"), "reservation снимается после прибытия")


func _assert_swap_is_rejected() -> void:
    var state := LogisticsTestFactory.two_workers_swapping_cells()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_true(state.cell_reservations.is_empty(), "взаимный обмен клетками не резервируется")
    assert_eq(state.get_worker(1).wait_reason, &"cell_occupied", "первый worker видит занятую клетку")
    assert_eq(state.get_worker(2).wait_reason, &"cell_occupied", "второй worker видит занятую клетку")
    assert_eq(state.worker_occupancy.get(&"1:1", 0), 1, "первый worker остаётся на месте")
    assert_eq(state.worker_occupancy.get(&"2:1", 0), 2, "второй worker остаётся на месте")


func _assert_repath_failure_is_explicit() -> void:
    var state := _assigned_state()
    var moving_worker := _first_moving_worker(state)
    assert_true(moving_worker != null, "для теста repath назначается worker")
    if moving_worker == null:
        return
    for cell: HexCellState in state.map_state.get_cells():
        if not cell.coord.equals(moving_worker.coord):
            cell.traversable = false
    state.repath_after_ticks = 1
    var job := state.get_job(moving_worker.job_id)
    MovementSystem.new().run(state, Pathfinder.new(), 11)
    assert_eq(moving_worker.wait_reason, &"no_path", "неуспешный repath имеет явную причину")
    assert_eq(job.wait_reason, &"no_path", "job сохраняет причину неуспешного repath")
    assert_eq(state.get_job(job.id), job, "неуспешный repath не удаляет job")


func _assert_repath_avoids_reserved_cell() -> void:
    var state := _assigned_state()
    var moving_worker := _first_moving_worker(state)
    assert_true(moving_worker != null, "для теста обхода назначается worker")
    if moving_worker == null:
        return
    var blocker: WorkerState
    for value: Variant in state.workers.values():
        var candidate := value as WorkerState
        if candidate.id != moving_worker.id:
            blocker = candidate
            break
    var blocked_target := moving_worker.route[moving_worker.route_index + 1]
    state.cell_reservations[blocked_target.key()] = blocker.id
    state.repath_after_ticks = 1
    MovementSystem.new().run(state, Pathfinder.new(), 11)
    var rebuilt := false
    for event: SimulationEvent in state.events:
        if event.code == &"route_rebuilt" and event.entity_id == moving_worker.id:
            rebuilt = true
            break
    assert_true(rebuilt, "длительное ожидание вызывает успешный repath")
    assert_eq(moving_worker.wait_ticks, 0, "успешный repath сбрасывает starvation counter")
    assert_true(
        moving_worker.route.size() < 2 or not moving_worker.route[1].equals(blocked_target),
        "новый маршрут обходит зарезервированную клетку"
    )


func _assigned_state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    WorkforceSystem.new().run(state, 10)
    JobSystem.new().run(state, 10)
    AssignmentSystem.new().run(state, Pathfinder.new(), 10)
    PathSystem.new().run(state, Pathfinder.new(), 10)
    return state


func _first_moving_worker(state: SimulationState) -> WorkerState:
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        if worker.action == WorkerState.TO_SOURCE:
            return worker
    return null
