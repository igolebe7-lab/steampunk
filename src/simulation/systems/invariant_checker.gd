class_name InvariantChecker
extends RefCounted


func check(state: SimulationState) -> Array[StringName]:
    var errors: Array[StringName] = []
    if state == null:
        return [&"missing_state"]
    if state.tick < 0:
        errors.append(&"invalid_tick")
    if state.map_state == null:
        errors.append(&"missing_map")
    if state.catalog == null:
        errors.append(&"missing_catalog")
    if state.map_state == null or state.catalog == null:
        return errors
    if (
        state.worker_ticks_per_hex <= 0
        or state.load_ticks <= 0
        or state.unload_ticks <= 0
        or state.repath_after_ticks <= 0
    ):
        _append_once(errors, &"invalid_simulation_timing")
    _check_telemetry(state, errors)

    var expected_occupancy: Dictionary = {}
    var maximum_id := 0
    var transfer_depot_count := 0
    for key in state.buildings:
        var entity_id := key as int
        var building := state.buildings[key] as BuildingState
        if building == null or entity_id <= 0 or building.id != entity_id:
            errors.append(&"invalid_building_id")
            continue
        maximum_id = maxi(maximum_id, entity_id)
        if building.priority < 0 or building.priority > 4:
            errors.append(&"invalid_building_priority")
        if not state.map_state.contains(building.coord):
            errors.append(&"building_out_of_bounds")

        var definition := state.catalog.get_building(building.definition_id)
        if definition == null:
            errors.append(&"unknown_building_definition")
            continue
        if definition.role == LogisticsPortDef.ROLE_TRANSFER_DEPOT:
            transfer_depot_count += 1
        _check_building_inventory(state, building, errors)
        for coord in _footprint_coords(building.coord, definition.footprint):
            if not state.map_state.contains(coord):
                errors.append(&"building_out_of_bounds")
                continue
            if expected_occupancy.has(coord.key()):
                errors.append(&"building_overlap")
            else:
                expected_occupancy[coord.key()] = entity_id
    if transfer_depot_count > 1:
        _append_once(errors, &"multiple_transfer_depots")

    var expected_worker_occupancy: Dictionary = {}
    var assigned_jobs: Dictionary = {}
    for key: Variant in state.workers.keys():
        var worker_id := key as int
        var worker := state.workers[key] as WorkerState
        if worker == null or worker_id <= 0 or worker.id != worker_id:
            _append_once(errors, &"invalid_worker_id")
            continue
        maximum_id = maxi(maximum_id, worker_id)
        if not state.map_state.contains(worker.coord):
            _append_once(errors, &"worker_out_of_bounds")
        elif state.occupied_cells.has(worker.coord.key()):
            _append_once(errors, &"worker_on_building")
        elif expected_worker_occupancy.has(worker.coord.key()):
            _append_once(errors, &"worker_overlap")
        else:
            expected_worker_occupancy[worker.coord.key()] = worker_id
        _check_worker_route(state, worker, errors)
        _check_worker_job(state, worker, assigned_jobs, errors)
        if worker.action == WorkerState.BLOCKED and worker.wait_reason.is_empty():
            _append_once(errors, &"blocked_without_reason")

    for key: Variant in state.jobs.keys():
        var job_id := key as int
        var job := state.jobs[key] as DeliveryJob
        if job == null or job_id <= 0 or job.id != job_id:
            _append_once(errors, &"invalid_job_id")
            continue
        if state.get_building(job.source_id) == null or state.get_building(job.destination_id) == null:
            _append_once(errors, &"unknown_job_building")
        if state.catalog.get_resource(job.resource_id) == null:
            _append_once(errors, &"unknown_job_resource")
        var job_link := state.logistics_links.get(job.link_id) as LogisticsLinkState
        if (
            job_link == null
            or job_link.source_id != job.source_id
            or job_link.destination_id != job.destination_id
            or job_link.resource_id != job.resource_id
        ):
            _append_once(errors, &"invalid_job_link")
        if job.worker_id > 0:
            var worker := state.get_worker(job.worker_id)
            if worker == null or worker.job_id != job.id:
                _append_once(errors, &"assignment_mismatch")
        elif job.state != DeliveryJob.QUEUED:
            _append_once(errors, &"assignment_mismatch")
        if job.state == DeliveryJob.BLOCKED and job.wait_reason.is_empty():
            _append_once(errors, &"blocked_without_reason")

    _check_worker_occupancy(state, expected_worker_occupancy, errors)
    _check_cell_reservations(state, errors)
    _check_logistics_links(state, errors)
    _check_reservation_ledger(state, errors)
    _check_resource_conservation(state, errors)

    if state.next_entity_id <= maximum_id:
        errors.append(&"invalid_next_entity_id")
    var maximum_job_id := 0
    for key: Variant in state.jobs.keys():
        maximum_job_id = maxi(maximum_job_id, key as int)
    if state.next_job_id <= maximum_job_id:
        _append_once(errors, &"invalid_next_job_id")
    var maximum_link_id := 0
    for key: Variant in state.logistics_links.keys():
        maximum_link_id = maxi(maximum_link_id, key as int)
    if state.next_link_id <= maximum_link_id:
        _append_once(errors, &"invalid_next_link_id")
    if expected_occupancy.size() != state.occupied_cells.size():
        errors.append(&"invalid_occupancy")
    else:
        for cell_key in expected_occupancy:
            if state.occupied_cells.get(cell_key) != expected_occupancy[cell_key]:
                errors.append(&"invalid_occupancy")
                break
    return errors


func _check_telemetry(state: SimulationState, errors: Array[StringName]) -> void:
    if (
        state.telemetry_window == null
        or state.telemetry_window.size() > TelemetryWindow.WINDOW_TICKS
        or state.telemetry_window.total_samples < state.telemetry_window.size()
    ):
        _append_once(errors, &"invalid_telemetry_window")
    else:
        var previous_tick := -1
        for sample: Dictionary in state.telemetry_window.ordered_samples():
            var tick := sample.get(&"tick", -1) as int
            if tick <= previous_tick:
                _append_once(errors, &"invalid_telemetry_window")
                break
            previous_tick = tick
    var report := state.diagnostic_report
    if report == null:
        _append_once(errors, &"invalid_diagnostic_report")
    elif report.code.is_empty():
        if report.loss_ticks != 0 or report.link_id != 0 or not report.cell_key.is_empty():
            _append_once(errors, &"invalid_diagnostic_report")
    elif not DiagnosticReport.is_supported_code(report.code) or report.loss_ticks <= 0:
        _append_once(errors, &"invalid_diagnostic_report")


func _check_building_inventory(
    state: SimulationState,
    building: BuildingState,
    errors: Array[StringName]
) -> void:
    var inventory_total := 0
    var incoming_total := 0
    for key: Variant in building.inventories.keys():
        var resource_id := key as StringName
        var amount := building.inventories[key] as int
        inventory_total += amount
        if amount < 0:
            _append_once(errors, &"invalid_inventory")
        if state.catalog.get_resource(resource_id) == null:
            _append_once(errors, &"unknown_inventory_resource")
    for key: Variant in building.outgoing_reserved.keys():
        var resource_id := key as StringName
        var amount := building.outgoing_reserved[key] as int
        if amount < 0 or amount > building.get_amount(resource_id):
            _append_once(errors, &"invalid_outgoing_reservation")
        if state.catalog.get_resource(resource_id) == null:
            _append_once(errors, &"unknown_inventory_resource")
    for key: Variant in building.incoming_reserved.keys():
        var resource_id := key as StringName
        var amount := building.incoming_reserved[key] as int
        incoming_total += amount
        if amount < 0:
            _append_once(errors, &"invalid_incoming_reservation")
        if state.catalog.get_resource(resource_id) == null:
            _append_once(errors, &"unknown_inventory_resource")
    if inventory_total < 0 or inventory_total > building.inventory_capacity:
        _append_once(errors, &"invalid_inventory")
    if inventory_total + incoming_total > building.inventory_capacity:
        _append_once(errors, &"invalid_incoming_reservation")


func _check_worker_route(
    state: SimulationState,
    worker: WorkerState,
    errors: Array[StringName]
) -> void:
    var previous: HexCoord
    for coord: HexCoord in worker.route:
        if (
            not state.map_state.contains(coord)
            or not state.map_state.get_cell(coord).traversable
            or state.occupied_cells.has(coord.key())
        ):
            _append_once(errors, &"invalid_worker_route")
        if previous != null and previous.distance_to(coord) != 1:
            _append_once(errors, &"invalid_worker_route")
        previous = coord
    if (
        worker.route_index < 0
        or (worker.route.is_empty() and worker.route_index != 0)
        or (not worker.route.is_empty() and worker.route_index >= worker.route.size())
    ):
        _append_once(errors, &"invalid_worker_route")
    if worker.segment_target == null:
        if worker.segment_progress != 0 or worker.segment_duration != 0:
            _append_once(errors, &"invalid_movement_segment")
    elif (
        not state.map_state.contains(worker.segment_target)
        or worker.segment_duration <= 0
        or worker.segment_progress < 0
        or worker.segment_progress >= worker.segment_duration
        or worker.coord.distance_to(worker.segment_target) != 1
        or worker.route_index + 1 >= worker.route.size()
        or not worker.route[worker.route_index + 1].equals(worker.segment_target)
    ):
        _append_once(errors, &"invalid_movement_segment")
    if (
        worker.segment_target != null
        and (state.cell_reservations.get(worker.segment_target.key(), 0) as int) != worker.id
    ):
        _append_once(errors, &"invalid_cell_reservation")


func _check_worker_job(
    state: SimulationState,
    worker: WorkerState,
    assigned_jobs: Dictionary,
    errors: Array[StringName]
) -> void:
    if worker.job_id <= 0:
        if worker.action != WorkerState.IDLE:
            _append_once(errors, &"assignment_mismatch")
        if worker.link_id != 0:
            var idle_link := state.logistics_links.get(worker.link_id) as LogisticsLinkState
            if idle_link == null or idle_link.is_closing or not idle_link.dispatch_enabled:
                _append_once(errors, &"worker_link_mismatch")
        if not worker.cargo_resource_id.is_empty():
            _append_once(errors, &"cargo_job_mismatch")
        return
    var job := state.get_job(worker.job_id)
    if job == null or job.worker_id != worker.id:
        _append_once(errors, &"assignment_mismatch")
        return
    if worker.link_id != job.link_id:
        _append_once(errors, &"worker_link_mismatch")
    if assigned_jobs.has(job.id):
        _append_once(errors, &"duplicate_job_assignment")
    assigned_jobs[job.id] = worker.id
    if not _worker_job_states_match(worker, job):
        _append_once(errors, &"worker_job_state_mismatch")
    if not worker.cargo_resource_id.is_empty():
        if worker.cargo_resource_id != job.resource_id:
            _append_once(errors, &"cargo_job_mismatch")
        if not worker.action in [
            WorkerState.AWAITING_DESTINATION_PATH,
            WorkerState.TO_DESTINATION,
            WorkerState.UNLOADING,
            WorkerState.BLOCKED,
        ]:
            _append_once(errors, &"cargo_job_mismatch")
        if state.catalog.get_resource(worker.cargo_resource_id) == null:
            _append_once(errors, &"unknown_cargo_resource")


func _check_worker_occupancy(
    state: SimulationState,
    expected: Dictionary,
    errors: Array[StringName]
) -> void:
    if expected.size() != state.worker_occupancy.size():
        _append_once(errors, &"invalid_worker_occupancy")
        return
    for key: Variant in expected.keys():
        if state.worker_occupancy.get(key, 0) != expected[key]:
            _append_once(errors, &"invalid_worker_occupancy")
            return


func _check_cell_reservations(state: SimulationState, errors: Array[StringName]) -> void:
    for key: Variant in state.cell_reservations.keys():
        var worker_id := state.cell_reservations[key] as int
        var worker := state.get_worker(worker_id)
        if (
            worker == null
            or worker.segment_target == null
            or worker.segment_target.key() != (key as StringName)
            or (
                (state.worker_occupancy.get(key, 0) as int) != 0
                and (state.worker_occupancy.get(key, 0) as int) != worker_id
            )
        ):
            _append_once(errors, &"invalid_cell_reservation")


func _check_logistics_links(state: SimulationState, errors: Array[StringName]) -> void:
    if not state.delivery_flows.is_empty():
        _append_once(errors, &"legacy_delivery_flows_in_state")
    var endpoints: Dictionary = {}
    var source_quotas: Dictionary = {}
    var source_workers: Dictionary = {}
    var system := LogisticsLinkSystem.new()
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        var worker_link := state.logistics_links.get(worker.link_id) as LogisticsLinkState
        if worker_link != null:
            source_workers[worker_link.source_id] = (
                (source_workers.get(worker_link.source_id, 0) as int) + 1
            )
    for key: Variant in state.logistics_links.keys():
        var link_id := key as int
        var link := state.logistics_links[key] as LogisticsLinkState
        if link == null or link.id <= 0 or link.id != link_id:
            _append_once(errors, &"invalid_logistics_link")
            continue
        var source := state.get_building(link.source_id)
        var destination := state.get_building(link.destination_id)
        if source == null or destination == null or source.id == destination.id:
            _append_once(errors, &"invalid_link_endpoint")
            continue
        var endpoint_key := "%d:%d:%s" % [link.source_id, link.destination_id, link.resource_id]
        if endpoints.has(endpoint_key):
            _append_once(errors, &"duplicate_link")
        endpoints[endpoint_key] = true
        if not link.is_closing:
            source_quotas[link.source_id] = (source_quotas.get(link.source_id, 0) as int) + link.quota
        var link_workers := 0
        for worker_value: Variant in state.workers.values():
            if (worker_value as WorkerState).link_id == link.id:
                link_workers += 1
        if link_workers > link.quota:
            _append_once(errors, &"link_quota_exceeded")
        if (
            state.catalog.get_resource(link.resource_id) == null
            or link.quota < 0
            or link.priority < 0
            or link.priority > 4
            or (link.is_closing and link.dispatch_enabled)
        ):
            _append_once(errors, &"invalid_logistics_link")
        if not link.is_closing and not system.is_compatible(
            state,
            link.source_id,
            link.destination_id,
            link.resource_id
        ):
            _append_once(errors, &"incompatible_link")
        if system.would_create_cycle(state, link.source_id, link.destination_id, link.id):
            _append_once(errors, &"link_cycle")
    for source_key: Variant in source_quotas.keys():
        var source_id := source_key as int
        var source := state.get_building(source_id)
        var definition: BuildingDef = (
            null if source == null else state.catalog.get_building(source.definition_id)
        )
        if definition == null:
            continue
        var slots := definition.outgoing_worker_slots(source.level)
        if (source_quotas[source_id] as int) > slots:
            _append_once(errors, &"source_slots_exceeded")
        if (source_workers.get(source_id, 0) as int) > slots:
            _append_once(errors, &"source_worker_slots_exceeded")


func _check_reservation_ledger(state: SimulationState, errors: Array[StringName]) -> void:
    var expected_outgoing: Dictionary = {}
    var expected_incoming: Dictionary = {}
    for value: Variant in state.jobs.values():
        var job := value as DeliveryJob
        if job == null:
            continue
        _increment_ledger(expected_incoming, job.destination_id, job.resource_id)
        var worker := state.get_worker(job.worker_id)
        var cargo_was_loaded := (
            worker != null
            and worker.cargo_resource_id == job.resource_id
        )
        if not cargo_was_loaded:
            _increment_ledger(expected_outgoing, job.source_id, job.resource_id)

    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        if not _ledger_matches(
            building.outgoing_reserved,
            expected_outgoing.get(building.id, {}) as Dictionary
        ):
            _append_once(errors, &"reservation_ledger_mismatch")
        if not _ledger_matches(
            building.incoming_reserved,
            expected_incoming.get(building.id, {}) as Dictionary
        ):
            _append_once(errors, &"reservation_ledger_mismatch")


func _increment_ledger(ledger: Dictionary, building_id: int, resource_id: StringName) -> void:
    var building_ledger: Dictionary = ledger.get(building_id, {}) as Dictionary
    building_ledger[resource_id] = (building_ledger.get(resource_id, 0) as int) + 1
    ledger[building_id] = building_ledger


func _ledger_matches(actual: Dictionary, expected: Dictionary) -> bool:
    var resource_ids: Dictionary = {}
    for key: Variant in actual.keys():
        resource_ids[key] = true
    for key: Variant in expected.keys():
        resource_ids[key] = true
    for key: Variant in resource_ids.keys():
        if (actual.get(key, 0) as int) != (expected.get(key, 0) as int):
            return false
    return true


func _worker_job_states_match(worker: WorkerState, job: DeliveryJob) -> bool:
    match job.state:
        DeliveryJob.ASSIGNED:
            return worker.action == WorkerState.ASSIGNED and worker.cargo_resource_id.is_empty()
        DeliveryJob.TO_SOURCE:
            return worker.action == WorkerState.TO_SOURCE and worker.cargo_resource_id.is_empty()
        DeliveryJob.LOADING:
            return worker.action == WorkerState.LOADING and worker.cargo_resource_id.is_empty()
        DeliveryJob.AWAITING_DESTINATION_PATH:
            return (
                worker.action == WorkerState.AWAITING_DESTINATION_PATH
                and worker.cargo_resource_id == job.resource_id
            )
        DeliveryJob.TO_DESTINATION:
            return (
                worker.action == WorkerState.TO_DESTINATION
                and worker.cargo_resource_id == job.resource_id
            )
        DeliveryJob.UNLOADING:
            return (
                worker.action == WorkerState.UNLOADING
                and worker.cargo_resource_id == job.resource_id
            )
        DeliveryJob.BLOCKED:
            return worker.action == WorkerState.BLOCKED
        _:
            return false


func _check_resource_conservation(state: SimulationState, errors: Array[StringName]) -> void:
    var world_totals: Dictionary = {}
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        for key: Variant in building.inventories.keys():
            var resource_id := key as StringName
            var amount: int = world_totals.get(resource_id, 0) as int
            world_totals[resource_id] = amount + (building.inventories[key] as int)
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        if not worker.cargo_resource_id.is_empty():
            var amount: int = world_totals.get(worker.cargo_resource_id, 0) as int
            world_totals[worker.cargo_resource_id] = amount + 1
    var resource_ids: Dictionary = {}
    for key: Variant in state.generated_totals.keys():
        resource_ids[key] = true
    for key: Variant in world_totals.keys():
        resource_ids[key] = true
    for key: Variant in resource_ids.keys():
        var generated: int = state.generated_totals.get(key, 0) as int
        var present: int = world_totals.get(key, 0) as int
        var consumed: int = state.consumed_totals.get(key, 0) as int
        if generated < 0 or consumed < 0 or generated != present + consumed:
            _append_once(errors, &"resource_conservation")


func _append_once(errors: Array[StringName], code: StringName) -> void:
    if not errors.has(code):
        errors.append(code)


func _footprint_coords(anchor: HexCoord, offsets: Array[Vector2i]) -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    if anchor == null:
        return result
    var anchor_row := anchor.r + (anchor.q - (anchor.q & 1)) / 2
    for offset in offsets:
        var column := anchor.q + offset.x
        var row := anchor_row + offset.y
        var axial_r := row - (column - (column & 1)) / 2
        result.append(HexCoord.new(column, axial_r))
    return result
