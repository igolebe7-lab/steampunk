class_name StateHasher
extends RefCounted


func canonicalize(state: SimulationState) -> String:
    return "v=6|tick=%d|revision=%d|seed=%d|next=%d|next_job=%d|next_link=%d|main=%d|topology=%d|map=%d,%d|timings=%d,%d,%d,%d|road_defs=[%s]|building_defs=[%s]|recipe_defs=[%s]|cells=[%s]|buildings=[%s]|workers=[%s]|jobs=[%s]|flows=[%s]|links=[%s]|production=[%s]|utility=[%s]|scenario=[%s]|generated=[%s]|delivered=[%s]|consumed=[%s]|telemetry=[%s]|diagnostic=[%s]" % [
        state.tick,
        state.revision,
        state.seed,
        state.next_entity_id,
        state.next_job_id,
        state.next_link_id,
        state.main_warehouse_id,
        int(state.logistics_topology_dirty),
        state.map_state.width,
        state.map_state.height,
        state.worker_ticks_per_hex,
        state.load_ticks,
        state.unload_ticks,
        state.repath_after_ticks,
        _encode_road_definitions(state),
        _encode_building_definitions(state),
        _encode_recipe_definitions(state),
        _encode_cells(state),
        _encode_buildings(state),
        _encode_workers(state),
        _encode_jobs(state),
        _encode_flows(state),
        _encode_links(state),
        _encode_production(state),
        _encode_utility_network(state),
        _encode_scenario(state.scenario_progress),
        _encode_int_dictionary(state.generated_totals),
        _encode_int_dictionary(state.delivered_totals),
        _encode_int_dictionary(state.consumed_totals),
        _encode_telemetry_window(state.telemetry_window),
        _encode_diagnostic_report(state.diagnostic_report),
    ]


func hash_state(state: SimulationState) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(canonicalize(state).to_utf8_buffer())
    return context.finish().hex_encode()


func _encode_telemetry_window(window: TelemetryWindow) -> String:
    return "total=%d,cumulative_main=%s,cumulative_links=%s,cumulative_jobs=%d,manual_water=%d,pipe_water=%d,samples=%s" % [
        window.total_samples,
        _encode_variant(window.cumulative_main_deliveries),
        _encode_variant(window.cumulative_link_deliveries),
        window.cumulative_completed_jobs,
        window.cumulative_manual_water_delivered,
        window.cumulative_pipe_water_delivered,
        "|".join(window.ordered_fingerprints()),
    ]


func _encode_diagnostic_report(report: DiagnosticReport) -> String:
    return "%s,%d,%d,%s" % [
        _encode_identifier(report.code),
        report.loss_ticks,
        report.link_id,
        _encode_identifier(report.cell_key),
    ]


func _encode_variant(value: Variant) -> String:
    match typeof(value):
        TYPE_DICTIONARY:
            var dictionary := value as Dictionary
            var keys := dictionary.keys()
            keys.sort_custom(func(left: Variant, right: Variant) -> bool:
                return _encode_variant(left) < _encode_variant(right)
            )
            var parts: PackedStringArray = []
            for key: Variant in keys:
                parts.append("%s=%s" % [_encode_variant(key), _encode_variant(dictionary[key])])
            return "d{%s}" % ";".join(parts)
        TYPE_ARRAY:
            var parts: PackedStringArray = []
            for item: Variant in value as Array:
                parts.append(_encode_variant(item))
            return "a[%s]" % ";".join(parts)
        TYPE_STRING_NAME:
            return "n:%s" % _encode_identifier(value as StringName)
        TYPE_STRING:
            return "s:%s" % (value as String).uri_encode()
        TYPE_INT:
            return "i:%d" % (value as int)
        TYPE_FLOAT:
            return "f:%s" % var_to_str(value)
        TYPE_BOOL:
            return "b:%d" % int(value as bool)
        TYPE_NIL:
            return "null"
        _:
            return "v:%s" % var_to_str(value)


func _encode_cells(state: SimulationState) -> String:
    var cells := state.map_state.get_cells()
    cells.sort_custom(_sort_cells)
    var parts: PackedStringArray = []
    for cell: HexCellState in cells:
        parts.append("%d,%d,%d,%d,%d" % [
            cell.coord.q,
            cell.coord.r,
            int(cell.traversable),
            cell.movement_cost,
            cell.road_level,
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
        var role := &""
        var max_level := 1
        var outgoing_worker_slots := 0
        var worker_slots_by_level: Array[int] = []
        var logistics_ports: Array[LogisticsPortDef] = []
        var definition_allows_main := true
        if definition != null:
            source_resource = definition.source_resource_id
            source_interval = definition.source_interval_ticks
            source_capacity = definition.source_capacity
            role = definition.role
            max_level = definition.max_level
            outgoing_worker_slots = definition.outgoing_worker_slots(building.level)
            worker_slots_by_level = definition.outgoing_worker_slots_by_level
            logistics_ports = definition.logistics_ports
            definition_allows_main = definition.allows_direct_delivery_to_main
        parts.append("%d,%s,%d,%d,%d,%d,%d,%d,%d,%s,%d,%s,%d,%d,slots=%d,levels=[%s],ports=[%s],def_main=%d,inv=[%s],out=[%s],in=[%s]" % [
            building.id,
            _encode_identifier(building.definition_id),
            building.coord.q,
            building.coord.r,
            building.priority,
            building.inventory_capacity,
            building.source_progress_ticks,
            building.level,
            int(building.allows_direct_delivery_to_main),
            _encode_identifier(role),
            max_level,
            _encode_identifier(source_resource),
            source_interval,
            source_capacity,
            outgoing_worker_slots,
            _encode_int_array(worker_slots_by_level),
            _encode_ports(logistics_ports),
            int(definition_allows_main),
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
        parts.append("%d,pos=%s,prev=%s,target=%s,segment=%d,%d,route=[%s],route_index=%d,job=%d,link=%d,cargo=%s,action=%s,wait=%s,%d,operation=%d" % [
            worker.id,
            _encode_coord(worker.coord),
            _encode_coord(worker.previous_coord),
            _encode_coord(worker.segment_target),
            worker.segment_progress,
            worker.segment_duration,
            _encode_route(worker.route),
            worker.route_index,
            worker.job_id,
            worker.link_id,
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
        parts.append("%d,%d,%d,%s,%d,%d,%s,%d,%d,%s" % [
            job.id,
            job.source_id,
            job.destination_id,
            _encode_identifier(job.resource_id),
            job.priority,
            job.created_tick,
            _encode_identifier(job.state),
            job.worker_id,
            job.link_id,
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


func _encode_links(state: SimulationState) -> String:
    var ids := _sorted_int_keys(state.logistics_links)
    var parts: PackedStringArray = []
    for link_id: int in ids:
        var link := state.logistics_links[link_id] as LogisticsLinkState
        parts.append("%d,%d,%d,%s,%d,%d,%d,%d,%d,%d" % [
            link.id,
            link.source_id,
            link.destination_id,
            _encode_identifier(link.resource_id),
            int(link.is_automatic),
            link.quota,
            link.priority,
            int(link.dispatch_enabled),
            int(link.is_closing),
            link.waiting_ticks,
        ])
    return ";".join(parts)


func _encode_road_definitions(state: SimulationState) -> String:
    var definitions := state.catalog.road_levels.duplicate()
    definitions.sort_custom(_sort_road_definitions)
    var parts: PackedStringArray = []
    for definition: RoadLevelDef in definitions:
        parts.append("%d,%d,%d" % [
            definition.level,
            definition.traversal_ticks,
            definition.upgrade_cost,
        ])
    return ";".join(parts)


func _encode_building_definitions(state: SimulationState) -> String:
    var definitions := state.catalog.buildings.duplicate()
    definitions.sort_custom(_sort_building_definitions)
    var parts: PackedStringArray = []
    for definition: BuildingDef in definitions:
        parts.append("%s,role=%s,max=%d,direct=%d,capacity=%d,source=%s,%d,%d,slots=[%s],ports=[%s],recipe=%s,utility=[%s],footprint=[%s]" % [
            _encode_identifier(definition.id),
            _encode_identifier(definition.role),
            definition.max_level,
            int(definition.allows_direct_delivery_to_main),
            definition.inventory_capacity,
            _encode_identifier(definition.source_resource_id),
            definition.source_interval_ticks,
            definition.source_capacity,
            _encode_int_array(definition.outgoing_worker_slots_by_level),
            _encode_ports(definition.logistics_ports),
            _encode_identifier(definition.production_recipe_id),
            _encode_utility_ports(definition.utility_ports),
            _encode_footprint(definition.footprint),
        ])
    return ";".join(parts)


func _encode_recipe_definitions(state: SimulationState) -> String:
    var definitions := state.catalog.recipes.duplicate()
    definitions.sort_custom(_sort_recipe_definitions)
    var parts: PackedStringArray = []
    for definition: RecipeDef in definitions:
        parts.append("%s,inputs=%s,amounts=%s,buffer=%d,duration=%d,result=%s" % [
            _encode_identifier(definition.id),
            _encode_variant(definition.input_resource_ids),
            _encode_variant(definition.input_amounts),
            definition.input_buffer_cycles,
            definition.duration_ticks,
            _encode_identifier(definition.result_code),
        ])
    return ";".join(parts)


func _encode_production(state: SimulationState) -> String:
    var parts: PackedStringArray = []
    for building_id: int in _sorted_int_keys(state.production_states):
        var production := state.production_states[building_id] as ProductionState
        parts.append("%d,%s,%s,progress=%d,cycles=%d,heat=%d,cooling=%d,reason=%s,linked=%d" % [
            production.building_id,
            _encode_identifier(production.recipe_id),
            _encode_identifier(production.status),
            production.progress_ticks,
            production.completed_cycles,
            production.heat_level,
            production.cooling_ticks,
            _encode_identifier(production.blocked_reason),
            production.linked_building_id,
        ])
    return ";".join(parts)


func _encode_utility_network(state: SimulationState) -> String:
    var keys := state.utility_network.segments.keys()
    keys.sort()
    var parts: PackedStringArray = []
    for key: Variant in keys:
        var segment := state.utility_network.segments[key] as UtilitySegmentState
        parts.append("%s,%s,component=%s" % [
            _encode_coord(segment.coord),
            _encode_identifier(segment.commodity_id),
            _encode_identifier(segment.component_id),
        ])
    return "revision=%d,resolved=%d,pipe=%d,manual=%d,segments=%s" % [
        state.utility_network.topology_revision,
        state.utility_network.resolved_topology_revision,
        state.utility_network.pipe_water_delivered,
        state.utility_network.manual_water_delivered,
        ";".join(parts),
    ]


func _encode_scenario(progress: ScenarioProgressState) -> String:
    if progress == null:
        return "missing"
    return "enabled=%d,phase=%s,observation=%d,entry=%d,active=%d,completed=%d,boiler=%d,hammer=%d,pump=%d,strikes=%d,baseline=%s,final=%s" % [
        int(progress.enabled),
        _encode_identifier(progress.phase),
        progress.observation_ticks,
        progress.phase_entry_tick,
        progress.active_start_tick,
        progress.completed_tick,
        progress.boiler_id,
        progress.hammer_id,
        progress.pump_station_id,
        progress.hammer_strikes,
        _encode_variant(progress.baseline_metrics),
        _encode_variant(progress.final_metrics),
    ]


func _encode_footprint(footprint: Array[Vector2i]) -> String:
    var cells: PackedStringArray = []
    for offset: Vector2i in footprint:
        cells.append("%d:%d" % [offset.x, offset.y])
    cells.sort()
    return ",".join(cells)


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


func _encode_int_array(values: Array[int]) -> String:
    var parts: PackedStringArray = []
    for value: int in values:
        parts.append(str(value))
    return ",".join(parts)


func _encode_ports(ports: Array[LogisticsPortDef]) -> String:
    var parts: PackedStringArray = []
    for port: LogisticsPortDef in ports:
        var roles: PackedStringArray = []
        for role: StringName in port.accepted_building_roles:
            roles.append(_encode_identifier(role))
        roles.sort()
        parts.append("%s,%s,roles=%s" % [
            _encode_identifier(port.direction),
            _encode_identifier(port.resource_id),
            ",".join(roles),
        ])
    parts.sort()
    return ";".join(parts)


func _encode_utility_ports(ports: Array[UtilityPortDef]) -> String:
    var parts: PackedStringArray = []
    for port: UtilityPortDef in ports:
        parts.append("%s,%s" % [
            _encode_identifier(port.direction),
            _encode_identifier(port.commodity_id),
        ])
    parts.sort()
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


func _sort_road_definitions(left: RoadLevelDef, right: RoadLevelDef) -> bool:
    return left.level < right.level


func _sort_building_definitions(left: BuildingDef, right: BuildingDef) -> bool:
    return String(left.id) < String(right.id)


func _sort_recipe_definitions(left: RecipeDef, right: RecipeDef) -> bool:
    return String(left.id) < String(right.id)
