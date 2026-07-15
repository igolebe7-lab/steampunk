class_name WorkforceSystem
extends RefCounted

const PRIORITY_WEIGHT := 10


func run(state: SimulationState, _target_tick: int) -> void:
    var link_counts: Dictionary = {}
    var source_counts: Dictionary = {}
    var free_workers: Array[WorkerState] = []
    for value: Variant in state.workers.values():
        var worker := value as WorkerState
        if _is_free(worker):
            worker.link_id = 0
            free_workers.append(worker)
            continue
        var link := state.logistics_links.get(worker.link_id) as LogisticsLinkState
        if link != null:
            link_counts[link.id] = (link_counts.get(link.id, 0) as int) + 1
            source_counts[link.source_id] = (source_counts.get(link.source_id, 0) as int) + 1
    free_workers.sort_custom(_worker_precedes)

    var links := _ordered_links(state)
    for link: LogisticsLinkState in links:
        if _has_demand(state, link) and (link_counts.get(link.id, 0) as int) < link.quota:
            link.waiting_ticks += 1
        elif (link_counts.get(link.id, 0) as int) >= link.quota or not _has_demand(state, link):
            link.waiting_ticks = 0

    for worker: WorkerState in free_workers:
        var selected := _select_link(state, links, link_counts, source_counts)
        if selected == null:
            break
        worker.link_id = selected.id
        link_counts[selected.id] = (link_counts.get(selected.id, 0) as int) + 1
        source_counts[selected.source_id] = (source_counts.get(selected.source_id, 0) as int) + 1
        selected.waiting_ticks = 0


func _select_link(
    state: SimulationState,
    links: Array[LogisticsLinkState],
    link_counts: Dictionary,
    source_counts: Dictionary
) -> LogisticsLinkState:
    var selected: LogisticsLinkState
    var selected_score := -1
    for link: LogisticsLinkState in links:
        if not _has_demand(state, link):
            continue
        if (link_counts.get(link.id, 0) as int) >= link.quota:
            continue
        if (source_counts.get(link.source_id, 0) as int) >= _source_slots(state, link.source_id):
            continue
        var score := link.priority * PRIORITY_WEIGHT + link.waiting_ticks
        if selected == null or score > selected_score or (score == selected_score and link.id < selected.id):
            selected = link
            selected_score = score
    return selected


func _has_demand(state: SimulationState, link: LogisticsLinkState) -> bool:
    if link == null or not link.dispatch_enabled or link.is_closing or link.quota <= 0:
        return false
    var source := state.get_building(link.source_id)
    var destination := state.get_building(link.destination_id)
    if source == null or destination == null:
        return false
    return (
        source.get_amount(link.resource_id) > 0
        and destination.free_capacity() > 0
    )


func _source_slots(state: SimulationState, source_id: int) -> int:
    var source := state.get_building(source_id)
    if source == null:
        return 0
    var definition := state.catalog.get_building(source.definition_id)
    return 0 if definition == null else definition.outgoing_worker_slots(source.level)


func _ordered_links(state: SimulationState) -> Array[LogisticsLinkState]:
    var links: Array[LogisticsLinkState] = []
    for value: Variant in state.logistics_links.values():
        links.append(value as LogisticsLinkState)
    links.sort_custom(_link_precedes)
    return links


func _is_free(worker: WorkerState) -> bool:
    return (
        worker.job_id == 0
        and worker.cargo_resource_id.is_empty()
        and worker.action == WorkerState.IDLE
    )


func _worker_precedes(left: WorkerState, right: WorkerState) -> bool:
    return left.id < right.id


func _link_precedes(left: LogisticsLinkState, right: LogisticsLinkState) -> bool:
    return left.id < right.id
