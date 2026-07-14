class_name StateHasher
extends RefCounted


func canonicalize(state: SimulationState) -> String:
    return "v=3|tick=%d|seed=%d|next=%d|next_job=%d|map=%d,%d|timings=%d,%d,%d,%d|cells=[%s]|buildings=[%s]|workers=[%s]|jobs=[%s]|flows=[%s]|worker_occupancy=[%s]|cell_reservations=[%s]|generated=[%s]|delivered=[%s]" % [
        state.tick,
        state.seed,
        state.next_entity_id,
        state.next_job_id,
        state.map_state.width,
        state.map_state.height,
        state.worker_ticks_per_hex,
        state.load_ticks,
        state.unload_ticks,
        state.repath_after_ticks,
        _encode_cells(state),
        _encode_buildings(state),
        _encode_workers(state),
        _encode_jobs(state),
        _encode_flows(state),
        _encode_int_dictionary(state.worker_occupancy),
        _encode_int_dictionary(state.cell_reservations),
        _encode_int_dictionary(state.generated_totals),
        _encode_int_dictionary(state.delivered_totals),
    ]


func hash_state(state: SimulationState) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(canonicalize(state).to_utf8_buffer())
    return context.finish().hex_encode()


func _encode_cells(state: SimulationState) -> String:
    var cells := state.map_state.get_cells()
    cells.sort_custom(_sort_cells)
    var parts: PackedStringArray = []
    for cell: HexCellState in cells:
        parts.append("%d,%d,%d,%d" % [
            cell.coord.q,
            cell.coord.r,
            int(cell.traversable),
            cell.movement_cost,
        ])
    return ";".join(parts)


func _encode_buildings(state: SimulationState) -> String:
    var ids := _sorted_int_keys(state.buildings)
    var parts: PackedStringArray = []
    for entity_id: int in ids:
        var building := state.get_building(entity_id)
        var definition := state.catalog.get_building(building.definition_id)
        var source_resource := &""
        var source_interval := 0
        var source_capacity := 0
        if definition != null:
            source_resource = definition.source_resource_id
            source_interval = definition.source_interval_ticks
            source_capacity = definition.source_capacity
        parts.append("%d,%s,%d,%d,%d,%d,%d,%s,%d,%d,inv=[%s],out=[%s],in=[%s]" % [
            building.id,
            _encode_identifier(building.definition_id),
            building.coord.q,
            building.coord.r,
            building.priority,
            building.inventory_capacity,
            building.source_progress_ticks,
            _encode_identifier(source_resource),
            source_interval,
            source_capacity,
            _encode_int_dictionary(building.inventories),
            _encode_int_dictionary(building.outgoing_reserved),
            _encode_int_dictionary(building.incoming_reserved),
        ])
    return ";".join(parts)


func _encode_workers(state: SimulationState) -> String:
    var ids := _sorted_int_keys(state.workers)
    var parts: PackedStringArray = []
    for worker_id: int in ids:
        var worker := state.get_worker(worker_id)
        parts.append("%d,pos=%s,prev=%s,target=%s,segment=%d,%d,route=[%s],route_index=%d,job=%d,cargo=%s,action=%s,wait=%s,%d,operation=%d" % [
            worker.id,
            _encode_coord(worker.coord),
            _encode_coord(worker.previous_coord),
            _encode_coord(worker.segment_target),
            worker.segment_progress,
            worker.segment_duration,
            _encode_route(worker.route),
            worker.route_index,
            worker.job_id,
            _encode_identifier(worker.cargo_resource_id),
            _encode_identifier(worker.action),
            _encode_identifier(worker.wait_reason),
            worker.wait_ticks,
            worker.operation_progress,
        ])
    return ";".join(parts)


func _encode_jobs(state: SimulationState) -> String:
    var ids := _sorted_int_keys(state.jobs)
    var parts: PackedStringArray = []
    for job_id: int in ids:
        var job := state.get_job(job_id)
        parts.append("%d,%d,%d,%s,%d,%d,%s,%d,%s" % [
            job.id,
            job.source_id,
            job.destination_id,
            _encode_identifier(job.resource_id),
            job.priority,
            job.created_tick,
            _encode_identifier(job.state),
            job.worker_id,
            _encode_identifier(job.wait_reason),
        ])
    return ";".join(parts)


func _encode_flows(state: SimulationState) -> String:
    var flows := state.delivery_flows.duplicate()
    flows.sort_custom(_sort_flows)
    var parts: PackedStringArray = []
    for flow: DeliveryFlowState in flows:
        parts.append("%d,%d,%d,%s,%d" % [
            flow.id,
            flow.source_id,
            flow.destination_id,
            _encode_identifier(flow.resource_id),
            flow.priority,
        ])
    return ";".join(parts)


func _encode_route(route: Array[HexCoord]) -> String:
    var parts: PackedStringArray = []
    for coord: HexCoord in route:
        parts.append(_encode_coord(coord))
    return ";".join(parts)


func _encode_coord(coord: HexCoord) -> String:
    if coord == null:
        return "-"
    return "%d:%d" % [coord.q, coord.r]


func _encode_int_dictionary(values: Dictionary) -> String:
    var keys: Array[String] = []
    for key: Variant in values.keys():
        keys.append(String(key as StringName))
    keys.sort()
    var parts: PackedStringArray = []
    for key: String in keys:
        var identifier := StringName(key)
        parts.append("%s=%d" % [_encode_identifier(identifier), values[identifier] as int])
    return ";".join(parts)


func _sorted_int_keys(values: Dictionary) -> Array[int]:
    var keys: Array[int] = []
    for key: Variant in values.keys():
        keys.append(key as int)
    keys.sort()
    return keys


func _encode_identifier(identifier: StringName) -> String:
    var value := String(identifier)
    return "%d:%s" % [value.length(), value]


func _sort_cells(left: HexCellState, right: HexCellState) -> bool:
    if left.coord.q == right.coord.q:
        return left.coord.r < right.coord.r
    return left.coord.q < right.coord.q


func _sort_flows(left: DeliveryFlowState, right: DeliveryFlowState) -> bool:
    return left.id < right.id
