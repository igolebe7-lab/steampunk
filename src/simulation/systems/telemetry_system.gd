class_name TelemetrySystem
extends RefCounted


func run(state: SimulationState, target_tick: int = -1) -> void:
    var tick := state.tick if target_tick < 0 else target_tick
    var sample := {
        &"tick": tick,
        &"main_deliveries": {},
        &"link_deliveries": {},
        &"job_latency_total": 0,
        &"completed_jobs": 0,
        &"moving_workers": 0,
        &"waiting_workers": 0,
        &"queue_depth": state.jobs.size(),
        &"link_load": {},
        &"cell_load": {},
        &"cell_conflicts": {},
        &"losses": {},
        &"loss_links": {},
        &"loss_cells": {},
    }
    _collect_workers(state, sample)
    _collect_events(state, sample)
    _collect_capacity_losses(state, sample)
    state.telemetry_window.append_sample(sample)
    state.telemetry = _snapshot(state)


func _collect_workers(state: SimulationState, sample: Dictionary) -> void:
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        if worker.action == WorkerState.TO_SOURCE or worker.action == WorkerState.TO_DESTINATION:
            sample[&"moving_workers"] = (sample[&"moving_workers"] as int) + 1
        if not worker.wait_reason.is_empty() and worker.wait_reason != &"no_job":
            sample[&"waiting_workers"] = (sample[&"waiting_workers"] as int) + 1
        if worker.link_id > 0:
            _increment(sample[&"link_load"] as Dictionary, worker.link_id)
        _increment(sample[&"cell_load"] as Dictionary, StringName(worker.coord.key()))
        if worker.wait_reason == &"no_path":
            _record_loss(sample, &"no_path", worker.link_id, StringName(worker.coord.key()))
        elif worker.wait_reason == &"cell_reserved" or worker.wait_reason == &"cell_occupied":
            _record_loss(sample, &"route_conflict", worker.link_id, StringName(worker.coord.key()))
    for value: Variant in state.jobs.values():
        var job := value as DeliveryJob
        if job.wait_reason == &"worker_shortage":
            _record_loss(sample, &"worker_shortage", job.link_id)
        elif job.wait_reason == &"no_path":
            _record_loss(sample, &"no_path", job.link_id)


func _collect_events(state: SimulationState, sample: Dictionary) -> void:
    for event: SimulationEvent in state.events:
        if event.code == &"cargo_delivered":
            _increment(sample[&"link_deliveries"] as Dictionary, event.link_id)
            if event.destination_id == state.main_warehouse_id:
                _increment(sample[&"main_deliveries"] as Dictionary, event.resource_id)
            sample[&"job_latency_total"] = (sample[&"job_latency_total"] as int) + event.metric_value
            sample[&"completed_jobs"] = (sample[&"completed_jobs"] as int) + 1
        elif event.code == &"worker_waiting" and event.reason in [&"cell_reserved", &"cell_occupied"]:
            _increment(sample[&"cell_conflicts"] as Dictionary, event.cell_key)
            _set_loss_attribution(sample, &"route_conflict", event.link_id, event.cell_key)


func _collect_capacity_losses(state: SimulationState, sample: Dictionary) -> void:
    var outgoing: Dictionary = {}
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.is_closing or not link.dispatch_enabled:
            continue
        outgoing[link.source_id] = true
        var source := state.get_building(link.source_id)
        var destination := state.get_building(link.destination_id)
        if source != null and destination != null and source.get_amount(link.resource_id) > 0:
            if destination.free_capacity() == 0:
                _record_loss(sample, &"destination_full", link.id)
            if _link_worker_count(state, link.id) == 0:
                _record_loss(sample, &"worker_shortage", link.id)

    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        if building.id == state.main_warehouse_id:
            continue
        var definition := state.catalog.get_building(building.definition_id)
        if definition == null:
            continue
        if definition.is_source() and building.inventory_total() >= building.inventory_capacity:
            _record_loss(sample, &"source_full")
        if building.inventory_total() > 0 and not outgoing.has(building.id):
            _record_loss(sample, &"no_destination")
        if (
            definition.role == LogisticsPortDef.ROLE_TRANSFER_DEPOT
            and building.inventory_total() >= building.inventory_capacity
        ):
            _record_loss(sample, &"relay_backlog")


func _snapshot(state: SimulationState) -> Dictionary:
    var main_throughput: Dictionary = {}
    for resource_value: Variant in state.telemetry_window.cumulative_main_deliveries.keys():
        var resource_id := resource_value as StringName
        main_throughput[resource_id] = state.telemetry_window.main_throughput_per_minute(resource_id)
    var link_throughput: Dictionary = {}
    for link_value: Variant in state.logistics_links.keys():
        var link_id := link_value as int
        link_throughput[link_id] = state.telemetry_window.link_throughput_per_minute(link_id)
    return {
        &"ready": state.telemetry_window.is_warm(),
        &"window_ticks": state.telemetry_window.size(),
        &"main_throughput_per_minute": main_throughput,
        &"link_throughput_per_minute": link_throughput,
        &"average_job_latency_ticks": state.telemetry_window.average_job_latency_ticks(),
        &"average_moving_workers": state.telemetry_window.average_moving_workers(),
        &"average_waiting_workers": state.telemetry_window.average_waiting_workers(),
        &"average_queue_depth": state.telemetry_window.average_queue_depth(),
    }


func _record_loss(
    sample: Dictionary,
    code: StringName,
    link_id: int = 0,
    cell_key: StringName = &""
) -> void:
    _increment(sample[&"losses"] as Dictionary, code)
    _set_loss_attribution(sample, code, link_id, cell_key)


func _set_loss_attribution(
    sample: Dictionary,
    code: StringName,
    link_id: int,
    cell_key: StringName
) -> void:
    if link_id > 0 and not (sample[&"loss_links"] as Dictionary).has(code):
        (sample[&"loss_links"] as Dictionary)[code] = link_id
    if not cell_key.is_empty() and not (sample[&"loss_cells"] as Dictionary).has(code):
        (sample[&"loss_cells"] as Dictionary)[code] = cell_key


func _increment(values: Dictionary, key: Variant) -> void:
    if key is StringName and (key as StringName).is_empty():
        return
    if key is int and (key as int) <= 0:
        return
    values[key] = (values.get(key, 0) as int) + 1


func _link_worker_count(state: SimulationState, link_id: int) -> int:
    var count := 0
    for value: Variant in state.workers.values():
        if (value as WorkerState).link_id == link_id:
            count += 1
    return count
