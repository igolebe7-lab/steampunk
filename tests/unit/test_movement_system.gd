extends TestCase


func run() -> Array[String]:
    _assert_workers_share_target_cell()
    _assert_workers_swap_cells()
    _assert_static_obstacles_still_block()
    _assert_repath_failure_is_explicit()
    return finish()


func _assert_workers_share_target_cell() -> void:
    var state := LogisticsTestFactory.two_workers_same_target()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_true(state.get_worker(1).segment_target != null, "первый носильщик начинает переход")
    assert_true(state.get_worker(2).segment_target != null, "второй носильщик начинает тот же переход")
    assert_eq(state.get_worker(1).wait_reason, &"", "первый не ждёт другого носильщика")
    assert_eq(state.get_worker(2).wait_reason, &"", "второй не ждёт другого носильщика")
    var movement_events := 0
    for event: SimulationEvent in state.events:
        if event.code == &"movement_started":
            movement_events += 1
    assert_eq(movement_events, 2, "оба перехода запускаются в один тик")
    for tick in range(2, 6):
        MovementSystem.new().run(state, Pathfinder.new(), tick)
    assert_eq(state.get_worker(1).coord.key(), &"2:1", "первый приходит в общую клетку")
    assert_eq(state.get_worker(2).coord.key(), &"2:1", "второй приходит в общую клетку")


func _assert_workers_swap_cells() -> void:
    var state := LogisticsTestFactory.two_workers_swapping_cells()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_true(state.get_worker(1).segment_target != null, "первый начинает встречный переход")
    assert_true(state.get_worker(2).segment_target != null, "второй начинает встречный переход")
    for tick in range(2, 6):
        MovementSystem.new().run(state, Pathfinder.new(), tick)
    assert_eq(state.get_worker(1).coord.key(), &"2:1", "первый занимает прежнюю клетку второго")
    assert_eq(state.get_worker(2).coord.key(), &"1:1", "второй занимает прежнюю клетку первого")


func _assert_static_obstacles_still_block() -> void:
    var building_state := LogisticsTestFactory.two_workers_same_target()
    building_state.occupied_cells[&"2:1"] = 99
    MovementSystem.new().run(building_state, Pathfinder.new(), 1)
    assert_eq(building_state.get_worker(1).segment_target, null, "здание блокирует переход")
    assert_eq(building_state.get_worker(1).wait_reason, &"no_path", "здание даёт причину no_path")

    var terrain_state := LogisticsTestFactory.two_workers_same_target()
    terrain_state.map_state.get_cell(HexCoord.new(2, 1)).traversable = false
    MovementSystem.new().run(terrain_state, Pathfinder.new(), 1)
    assert_eq(terrain_state.get_worker(2).segment_target, null, "непроходимая местность блокирует переход")
    assert_eq(terrain_state.get_worker(2).wait_reason, &"no_path", "местность даёт причину no_path")


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
