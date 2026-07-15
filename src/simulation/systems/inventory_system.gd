class_name InventorySystem
extends RefCounted


func run(state: SimulationState, target_tick: int) -> void:
    var workers: Array[WorkerState] = []
    for value: Variant in state.workers.values():
        workers.append(value as WorkerState)
    workers.sort_custom(_worker_precedes)

    for worker: WorkerState in workers:
        if worker.action == WorkerState.LOADING:
            _advance_loading(state, worker, target_tick)
        elif worker.action == WorkerState.UNLOADING:
            _advance_unloading(state, worker, target_tick)


func _advance_loading(state: SimulationState, worker: WorkerState, target_tick: int) -> void:
    worker.operation_progress += 1
    if worker.operation_progress < state.load_ticks:
        return
    var job := state.get_job(worker.job_id)
    if job == null:
        _release_orphan(worker)
        return
    var source := state.get_building(job.source_id)
    if (
        source == null
        or source.get_amount(job.resource_id) < 1
        or source.get_outgoing_reserved(job.resource_id) < 1
        or not worker.cargo_resource_id.is_empty()
    ):
        _block_operation(worker, job, &"missing_cargo")
        return

    source.remove_amount(job.resource_id, 1)
    source.release_outgoing(job.resource_id, 1)
    worker.cargo_resource_id = job.resource_id
    worker.operation_progress = 0
    worker.route.clear()
    worker.route_index = 0
    worker.action = WorkerState.AWAITING_DESTINATION_PATH
    worker.wait_reason = &""
    job.state = DeliveryJob.AWAITING_DESTINATION_PATH
    job.wait_reason = &""
    state.events.append(SimulationEvent.new(&"cargo_loaded", target_tick, worker.id, job.id, job.resource_id))


func _advance_unloading(state: SimulationState, worker: WorkerState, target_tick: int) -> void:
    worker.operation_progress += 1
    if worker.operation_progress < state.unload_ticks:
        return
    var job := state.get_job(worker.job_id)
    if job == null:
        _release_orphan(worker)
        return
    var destination := state.get_building(job.destination_id)
    if (
        destination == null
        or worker.cargo_resource_id != job.resource_id
        or destination.get_incoming_reserved(job.resource_id) < 1
        or destination.inventory_total() >= destination.inventory_capacity
    ):
        _block_operation(worker, job, &"unload_blocked")
        return

    if not destination.add_amount(job.resource_id, 1):
        _block_operation(worker, job, &"unload_blocked")
        return
    state.logistics_topology_dirty = true
    destination.release_incoming(job.resource_id, 1)
    worker.cargo_resource_id = &""
    worker.operation_progress = 0
    worker.route.clear()
    worker.route_index = 0
    worker.job_id = 0
    worker.action = WorkerState.IDLE
    worker.wait_reason = &"no_job"
    worker.wait_ticks = 0
    var link := state.logistics_links.get(job.link_id) as LogisticsLinkState
    if link == null or link.is_closing or not link.dispatch_enabled:
        worker.link_id = 0
    var delivered: int = state.delivered_totals.get(job.resource_id, 0) as int
    state.delivered_totals[job.resource_id] = delivered + 1
    var destination_definition := state.catalog.get_building(destination.definition_id)
    if (
        job.resource_id == &"water"
        and destination_definition != null
        and destination_definition.role == LogisticsPortDef.ROLE_PRODUCTION
    ):
        state.utility_network.manual_water_delivered += 1
        state.telemetry_window.cumulative_manual_water_delivered += 1
    state.jobs.erase(job.id)
    var event := SimulationEvent.new(&"cargo_delivered", target_tick, worker.id, job.id, job.resource_id)
    event.link_id = job.link_id
    event.destination_id = job.destination_id
    event.metric_value = maxi(target_tick - job.created_tick, 0)
    state.events.append(event)


func _block_operation(worker: WorkerState, job: DeliveryJob, reason: StringName) -> void:
    worker.action = WorkerState.BLOCKED
    worker.wait_reason = reason
    worker.operation_progress = 0
    job.state = DeliveryJob.BLOCKED
    job.wait_reason = reason


func _release_orphan(worker: WorkerState) -> void:
    worker.job_id = 0
    worker.link_id = 0
    worker.action = WorkerState.IDLE
    worker.wait_reason = &"no_job"
    worker.operation_progress = 0


func _worker_precedes(left: WorkerState, right: WorkerState) -> bool:
    return left.id < right.id
