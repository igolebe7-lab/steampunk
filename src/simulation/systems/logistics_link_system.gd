class_name LogisticsLinkSystem
extends RefCounted

const WOOD := &"wood"
const INF := 1 << 30


func run(state: SimulationState, pathfinder: Pathfinder) -> void:
    _cleanup_closing_links(state)
    if not state.logistics_topology_dirty:
        return

    var source_ids := _sorted_building_ids(state)
    for source_id: int in source_ids:
        var source := state.get_building(source_id)
        for resource_id: StringName in _output_resources(state, source):
            _ensure_automatic_link(state, pathfinder, source, resource_id)
    state.logistics_topology_dirty = false


func create_manual_link(
    state: SimulationState,
    pathfinder: Pathfinder,
    source_id: int,
    destination_id: int,
    resource_id: StringName,
    command_id: StringName
) -> CommandResult:
    var existing := _find_duplicate(state, source_id, destination_id, resource_id)
    if existing != null and existing.is_automatic:
        existing.is_automatic = false
        return CommandResult.success(command_id, {&"link_id": existing.id})
    if existing != null:
        return CommandResult.rejected(&"duplicate_link", command_id)
    if would_create_cycle(state, source_id, destination_id):
        return CommandResult.rejected(&"link_cycle", command_id)
    if not is_compatible(state, source_id, destination_id, resource_id):
        return CommandResult.rejected(&"incompatible_link", command_id)
    if _path_cost(state, pathfinder, source_id, destination_id) >= INF:
        return CommandResult.rejected(&"no_path", command_id)

    _remove_automatic_links(state, source_id, resource_id)
    var link := _add_link(state, source_id, destination_id, resource_id, false, 1, 2)
    return CommandResult.success(command_id, {&"link_id": link.id})


func remove_link(state: SimulationState, link_id: int, command_id: StringName) -> CommandResult:
    var link := state.logistics_links.get(link_id) as LogisticsLinkState
    if link == null:
        return CommandResult.rejected(&"unknown_link", command_id)
    _begin_removal(state, link)
    state.logistics_topology_dirty = true
    return CommandResult.success(command_id, {&"link_id": link_id})


func remove_source_links(state: SimulationState, source_id: int, resource_id: StringName) -> void:
    var ids: Array[int] = []
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.source_id == source_id and link.resource_id == resource_id:
            ids.append(link.id)
    ids.sort()
    for link_id: int in ids:
        var link := state.logistics_links.get(link_id) as LogisticsLinkState
        if link != null:
            _begin_removal(state, link)
    state.logistics_topology_dirty = true


func is_compatible(
    state: SimulationState,
    source_id: int,
    destination_id: int,
    resource_id: StringName
) -> bool:
    if source_id <= 0 or destination_id <= 0 or source_id == destination_id:
        return false
    var source := state.get_building(source_id)
    var destination := state.get_building(destination_id)
    if source == null or destination == null or state.catalog.get_resource(resource_id) == null:
        return false
    var source_definition := state.catalog.get_building(source.definition_id)
    var destination_definition := state.catalog.get_building(destination.definition_id)
    if source_definition == null or destination_definition == null:
        return false
    if destination.inventory_capacity <= 0:
        return false

    if source_definition.role == LogisticsPortDef.ROLE_SOURCE:
        if not destination_definition.role in [
            LogisticsPortDef.ROLE_STORAGE,
            LogisticsPortDef.ROLE_MAIN_WAREHOUSE,
            LogisticsPortDef.ROLE_TRANSFER_DEPOT,
        ]:
            return false
        if (
            destination_definition.role == LogisticsPortDef.ROLE_MAIN_WAREHOUSE
            and not source.allows_direct_delivery_to_main
        ):
            return false
        for port: LogisticsPortDef in source_definition.logistics_ports:
            if (
                port.direction == LogisticsPortDef.DIRECTION_OUTPUT
                and port.resource_id == resource_id
                and port.accepted_building_roles.has(destination_definition.role)
            ):
                return true
        return false
    return (
        source_definition.role == LogisticsPortDef.ROLE_TRANSFER_DEPOT
        and destination_definition.role == LogisticsPortDef.ROLE_MAIN_WAREHOUSE
        and resource_id == WOOD
    )


func would_create_cycle(
    state: SimulationState,
    source_id: int,
    destination_id: int,
    ignored_link_id: int = 0
) -> bool:
    if source_id == destination_id:
        return true
    var pending: Array[int] = [destination_id]
    var visited: Dictionary = {}
    while not pending.is_empty():
        var current := pending.pop_front() as int
        if current == source_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for value: Variant in state.logistics_links.values():
            var link := value as LogisticsLinkState
            if link.id != ignored_link_id and link.source_id == current:
                pending.append(link.destination_id)
    return false


func _ensure_automatic_link(
    state: SimulationState,
    pathfinder: Pathfinder,
    source: BuildingState,
    resource_id: StringName
) -> void:
    var automatic: LogisticsLinkState
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.source_id != source.id or link.resource_id != resource_id or link.is_closing:
            continue
        if not link.is_automatic:
            return
        automatic = link
    if automatic != null:
        if (
            is_compatible(state, source.id, automatic.destination_id, resource_id)
            and _path_cost(state, pathfinder, source.id, automatic.destination_id) < INF
        ):
            return
        _begin_removal(state, automatic)

    var selected_id := 0
    var selected_cost := INF
    var building_ids := _sorted_building_ids(state)
    for destination_id: int in building_ids:
        if not is_compatible(state, source.id, destination_id, resource_id):
            continue
        var cost := _path_cost(state, pathfinder, source.id, destination_id)
        if cost >= INF:
            continue
        if (
            selected_id == 0
            or cost < selected_cost
            or (cost == selected_cost and _destination_precedes(state, destination_id, selected_id))
        ):
            selected_id = destination_id
            selected_cost = cost
    if selected_id > 0:
        _add_link(state, source.id, selected_id, resource_id, true, 1, source.priority)


func _add_link(
    state: SimulationState,
    source_id: int,
    destination_id: int,
    resource_id: StringName,
    is_automatic: bool,
    quota: int,
    priority: int
) -> LogisticsLinkState:
    var link := LogisticsLinkState.new(
        state.next_link_id,
        source_id,
        destination_id,
        resource_id,
        is_automatic,
        quota,
        priority
    )
    state.logistics_links[link.id] = link
    state.next_link_id += 1
    return link


func _begin_removal(state: SimulationState, link: LogisticsLinkState) -> void:
    link.dispatch_enabled = false
    var has_active_cargo := false
    var job_ids: Array[int] = []
    for key: Variant in state.jobs.keys():
        job_ids.append(key as int)
    job_ids.sort()
    for job_id: int in job_ids:
        var job := state.get_job(job_id)
        if job == null or job.link_id != link.id:
            continue
        var worker := state.get_worker(job.worker_id)
        if worker != null and worker.cargo_resource_id == job.resource_id:
            has_active_cargo = true
            continue
        _cancel_job(state, job, worker)
    if has_active_cargo:
        link.is_closing = true
    else:
        state.logistics_links.erase(link.id)


func _cancel_job(state: SimulationState, job: DeliveryJob, worker: WorkerState) -> void:
    var source := state.get_building(job.source_id)
    var destination := state.get_building(job.destination_id)
    if source != null and source.get_outgoing_reserved(job.resource_id) > 0:
        source.release_outgoing(job.resource_id, 1)
    if destination != null and destination.get_incoming_reserved(job.resource_id) > 0:
        destination.release_incoming(job.resource_id, 1)
    if worker != null:
        worker.job_id = 0
        worker.link_id = 0
        worker.route.clear()
        worker.route_index = 0
        worker.action = WorkerState.IDLE
        worker.wait_reason = &"no_job"
        worker.operation_progress = 0
        _release_worker_cell_reservations(state, worker.id)
    state.jobs.erase(job.id)


func _cleanup_closing_links(state: SimulationState) -> void:
    var active_link_ids: Dictionary = {}
    for value: Variant in state.jobs.values():
        active_link_ids[(value as DeliveryJob).link_id] = true
    var ids: Array[int] = []
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.is_closing and not active_link_ids.has(link.id):
            ids.append(link.id)
    for link_id: int in ids:
        state.logistics_links.erase(link_id)


func _remove_automatic_links(state: SimulationState, source_id: int, resource_id: StringName) -> void:
    var links: Array[LogisticsLinkState] = []
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.source_id == source_id and link.resource_id == resource_id and link.is_automatic:
            links.append(link)
    links.sort_custom(_link_precedes)
    for link: LogisticsLinkState in links:
        _begin_removal(state, link)


func _find_duplicate(
    state: SimulationState,
    source_id: int,
    destination_id: int,
    resource_id: StringName
) -> LogisticsLinkState:
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if (
            link.source_id == source_id
            and link.destination_id == destination_id
            and link.resource_id == resource_id
            and not link.is_closing
        ):
            return link
    return null


func _output_resources(state: SimulationState, building: BuildingState) -> Array[StringName]:
    var result: Array[StringName] = []
    var definition := state.catalog.get_building(building.definition_id)
    if definition == null:
        return result
    if definition.role == LogisticsPortDef.ROLE_SOURCE:
        for port: LogisticsPortDef in definition.logistics_ports:
            if port.direction == LogisticsPortDef.DIRECTION_OUTPUT and not result.has(port.resource_id):
                result.append(port.resource_id)
    elif definition.role == LogisticsPortDef.ROLE_TRANSFER_DEPOT:
        result.append(WOOD)
    result.sort()
    return result


func _path_cost(
    state: SimulationState,
    pathfinder: Pathfinder,
    source_id: int,
    destination_id: int
) -> int:
    var starts := pathfinder.interaction_cells(state, source_id)
    var goals := pathfinder.interaction_cells(state, destination_id)
    var best := INF
    for start: HexCoord in starts:
        var result := pathfinder.find_path(state, start, goals)
        if result.is_success():
            best = mini(best, result.cost)
    return best


func _destination_precedes(state: SimulationState, left_id: int, right_id: int) -> bool:
    var left := state.get_building(left_id)
    var right := state.get_building(right_id)
    if left.coord.q != right.coord.q:
        return left.coord.q < right.coord.q
    if left.coord.r != right.coord.r:
        return left.coord.r < right.coord.r
    return left.id < right.id


func _sorted_building_ids(state: SimulationState) -> Array[int]:
    var ids: Array[int] = []
    for key: Variant in state.buildings.keys():
        ids.append(key as int)
    ids.sort()
    return ids


func _release_worker_cell_reservations(state: SimulationState, worker_id: int) -> void:
    var keys: Array[StringName] = []
    for key: Variant in state.cell_reservations.keys():
        if (state.cell_reservations[key] as int) == worker_id:
            keys.append(key as StringName)
    for key: StringName in keys:
        state.cell_reservations.erase(key)


func _link_precedes(left: LogisticsLinkState, right: LogisticsLinkState) -> bool:
    return left.id < right.id
