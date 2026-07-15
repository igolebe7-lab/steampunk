class_name AssignmentSystem
extends RefCounted


func run(state: SimulationState, pathfinder: Pathfinder, target_tick: int) -> void:
    var jobs: Array[DeliveryJob] = []
    for value: Variant in state.jobs.values():
        var job := value as DeliveryJob
        if job.state == DeliveryJob.QUEUED:
            jobs.append(job)
    jobs.sort_custom(_job_precedes)

    for job: DeliveryJob in jobs:
        var goals := pathfinder.interaction_cells(state, job.source_id)
        var selected_worker: WorkerState
        var selected_cost := 1 << 30

        var workers: Array[WorkerState] = []
        for value: Variant in state.workers.values():
            var worker := value as WorkerState
            if worker.job_id == 0 and worker.action == WorkerState.IDLE:
                workers.append(worker)
        workers.sort_custom(_worker_precedes)

        for worker: WorkerState in workers:
            var result := pathfinder.find_path(state, worker.coord, goals)
            if not result.is_success():
                continue
            if result.cost < selected_cost:
                selected_worker = worker
                selected_cost = result.cost

        if selected_worker == null:
            job.wait_reason = &"no_path"
            continue

        job.worker_id = selected_worker.id
        job.state = DeliveryJob.ASSIGNED
        job.wait_reason = &""
        selected_worker.job_id = job.id
        selected_worker.link_id = job.link_id
        selected_worker.action = WorkerState.ASSIGNED
        selected_worker.wait_reason = &""
        selected_worker.wait_ticks = 0
        state.events.append(SimulationEvent.new(
            &"job_assigned",
            target_tick,
            selected_worker.id,
            job.id,
            job.resource_id
        ))


func _job_precedes(left: DeliveryJob, right: DeliveryJob) -> bool:
    if left.priority != right.priority:
        return left.priority > right.priority
    if left.created_tick != right.created_tick:
        return left.created_tick < right.created_tick
    return left.id < right.id


func _worker_precedes(left: WorkerState, right: WorkerState) -> bool:
    return left.id < right.id
