class_name MovementSystem
extends RefCounted


func run(state: SimulationState, pathfinder: Pathfinder, target_tick: int) -> void:
    var workers := _ordered_workers(state)
    for worker: WorkerState in workers:
        _advance_segment(state, worker, target_tick)

    for worker: WorkerState in workers:
        if worker.segment_target != null or not _is_moving(worker):
            continue
        if worker.route_index >= worker.route.size() - 1:
            _start_operation(state, worker, target_tick)
            continue
        _try_start_segment(state, pathfinder, worker, target_tick)


func _advance_segment(state: SimulationState, worker: WorkerState, target_tick: int) -> void:
    if worker.segment_target == null:
        return
    worker.segment_progress += 1
    if worker.segment_progress < worker.segment_duration:
        return

    var target := worker.segment_target
    worker.previous_coord = worker.coord
    worker.coord = target
    worker.route_index += 1
    worker.segment_target = null
    worker.segment_progress = 0
    worker.segment_duration = 0
    worker.wait_reason = &""
    worker.wait_ticks = 0
    state.events.append(SimulationEvent.new(&"worker_arrived", target_tick, worker.id, worker.job_id))


func _try_start_segment(
    state: SimulationState,
    pathfinder: Pathfinder,
    worker: WorkerState,
    target_tick: int
) -> void:
    var target := worker.route[worker.route_index + 1]
    var target_key := target.key()
    var cell := state.map_state.get_cell(target)
    if cell == null or not cell.traversable or state.occupied_cells.has(target_key):
        _record_wait(state, worker, &"no_path", target_tick, target_key)
        _try_repath(state, pathfinder, worker, target_tick)
        return

    worker.segment_target = target
    worker.segment_progress = 0
    var road := state.catalog.get_road_level(cell.road_level)
    worker.segment_duration = (
        state.worker_ticks_per_hex * cell.movement_cost
        if road == null
        else road.traversal_ticks * cell.movement_cost
    )
    worker.wait_reason = &""
    worker.wait_ticks = 0
    state.events.append(SimulationEvent.new(&"movement_started", target_tick, worker.id, worker.job_id))


func _start_operation(state: SimulationState, worker: WorkerState, target_tick: int) -> void:
    var job := state.get_job(worker.job_id)
    if job == null:
        worker.action = WorkerState.IDLE
        worker.wait_reason = &"no_job"
        worker.job_id = 0
        return
    worker.operation_progress = 0
    if worker.action == WorkerState.TO_SOURCE:
        worker.action = WorkerState.LOADING
        job.state = DeliveryJob.LOADING
        state.events.append(SimulationEvent.new(&"loading_started", target_tick, worker.id, job.id, job.resource_id))
    elif worker.action == WorkerState.TO_DESTINATION:
        worker.action = WorkerState.UNLOADING
        job.state = DeliveryJob.UNLOADING
        state.events.append(SimulationEvent.new(&"unloading_started", target_tick, worker.id, job.id, job.resource_id))


func _record_wait(
    state: SimulationState,
    worker: WorkerState,
    reason: StringName,
    target_tick: int,
    cell_key: StringName = &""
) -> void:
    worker.wait_reason = reason
    worker.wait_ticks += 1
    var event := SimulationEvent.new(&"worker_waiting", target_tick, worker.id, worker.job_id)
    event.link_id = worker.link_id
    event.cell_key = cell_key
    event.reason = reason
    state.events.append(event)


func _try_repath(state: SimulationState, pathfinder: Pathfinder, worker: WorkerState, target_tick: int) -> void:
    if state.repath_after_ticks <= 0 or worker.wait_ticks % state.repath_after_ticks != 0:
        return
    var job := state.get_job(worker.job_id)
    if job == null:
        return
    var building_id := job.source_id if worker.action == WorkerState.TO_SOURCE else job.destination_id
    var goals := pathfinder.interaction_cells(state, building_id)
    var result := pathfinder.find_path(state, worker.coord, goals)
    if not result.is_success():
        worker.wait_reason = &"no_path"
        job.wait_reason = &"no_path"
        state.events.append(SimulationEvent.new(&"repath_failed", target_tick, worker.id, job.id, job.resource_id))
        return
    worker.route = result.path
    worker.route_index = 0
    worker.wait_reason = &""
    worker.wait_ticks = 0
    job.wait_reason = &""
    state.events.append(SimulationEvent.new(&"route_rebuilt", target_tick, worker.id, job.id, job.resource_id))


func _ordered_workers(state: SimulationState) -> Array[WorkerState]:
    var workers: Array[WorkerState] = []
    for value: Variant in state.workers.values():
        workers.append(value as WorkerState)
    workers.sort_custom(_worker_id_precedes)
    return workers


func _is_moving(worker: WorkerState) -> bool:
    return worker.action == WorkerState.TO_SOURCE or worker.action == WorkerState.TO_DESTINATION


func _worker_id_precedes(left: WorkerState, right: WorkerState) -> bool:
    return left.id < right.id
