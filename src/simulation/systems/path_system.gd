class_name PathSystem
extends RefCounted


func run(state: SimulationState, pathfinder: Pathfinder, target_tick: int) -> void:
    var workers: Array[WorkerState] = []
    for value: Variant in state.workers.values():
        workers.append(value as WorkerState)
    workers.sort_custom(_worker_precedes)

    for worker: WorkerState in workers:
        var job := state.get_job(worker.job_id)
        if job == null:
            continue
        if worker.action == WorkerState.ASSIGNED:
            _build_route(state, pathfinder, worker, job, job.source_id, WorkerState.TO_SOURCE, DeliveryJob.TO_SOURCE, target_tick)
        elif worker.action == WorkerState.AWAITING_DESTINATION_PATH:
            _build_route(state, pathfinder, worker, job, job.destination_id, WorkerState.TO_DESTINATION, DeliveryJob.TO_DESTINATION, target_tick)


func _build_route(
    state: SimulationState,
    pathfinder: Pathfinder,
    worker: WorkerState,
    job: DeliveryJob,
    building_id: int,
    worker_action: StringName,
    job_state: StringName,
    target_tick: int
) -> void:
    var goals := pathfinder.interaction_cells(state, building_id)
    var result := pathfinder.find_path(state, worker.coord, goals)
    if not result.is_success():
        _block_worker(state, worker, job, target_tick)
        return

    worker.route = result.path
    worker.route_index = 0
    worker.action = worker_action
    worker.wait_reason = &""
    worker.wait_ticks = 0
    job.state = job_state
    job.wait_reason = &""
    state.events.append(SimulationEvent.new(
        &"route_built",
        target_tick,
        worker.id,
        job.id,
        job.resource_id
    ))


func _block_worker(state: SimulationState, worker: WorkerState, job: DeliveryJob, target_tick: int) -> void:
    worker.route.clear()
    worker.route_index = 0
    worker.action = WorkerState.BLOCKED
    worker.wait_reason = &"no_path"
    job.state = DeliveryJob.BLOCKED
    job.wait_reason = &"no_path"
    state.events.append(SimulationEvent.new(
        &"route_blocked",
        target_tick,
        worker.id,
        job.id,
        job.resource_id
    ))


func _worker_precedes(left: WorkerState, right: WorkerState) -> bool:
    return left.id < right.id
