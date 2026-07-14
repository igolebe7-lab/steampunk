class_name TelemetrySystem
extends RefCounted


func run(state: SimulationState) -> void:
    var idle := 0
    var moving := 0
    var waiting := 0
    var carrying := 0
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        if worker.action == WorkerState.IDLE:
            idle += 1
        if worker.action == WorkerState.TO_SOURCE or worker.action == WorkerState.TO_DESTINATION:
            moving += 1
        if not worker.wait_reason.is_empty() and worker.wait_reason != &"no_job":
            waiting += 1
        if not worker.cargo_resource_id.is_empty():
            carrying += 1
    state.telemetry = {
        &"workers_idle": idle,
        &"workers_moving": moving,
        &"workers_waiting": waiting,
        &"workers_carrying": carrying,
        &"jobs_active": state.jobs.size(),
    }
