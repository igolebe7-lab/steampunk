class_name JobSystem
extends RefCounted


func run(state: SimulationState, target_tick: int) -> void:
    var links: Array[LogisticsLinkState] = []
    for value: Variant in state.logistics_links.values():
        links.append(value as LogisticsLinkState)
    links.sort_custom(_link_precedes)

    for link: LogisticsLinkState in links:
        if not link.dispatch_enabled or link.is_closing:
            continue
        var source := state.get_building(link.source_id)
        var destination := state.get_building(link.destination_id)
        if source == null or destination == null:
            continue

        var worker_slots := _worker_count(state, link.id)
        var active_jobs := _job_count(state, link.id)
        var jobs_to_create := mini(worker_slots, link.quota) - active_jobs
        if jobs_to_create <= 0:
            continue
        var available := source.get_amount(link.resource_id) - source.get_outgoing_reserved(link.resource_id)
        var capacity := demand_capacity(state, link)
        while available > 0 and capacity > 0 and jobs_to_create > 0:
            if not source.reserve_outgoing(link.resource_id, 1):
                break
            if not destination.reserve_incoming(link.resource_id, 1):
                source.release_outgoing(link.resource_id, 1)
                break

            var job := DeliveryJob.new(
                state.next_job_id,
                link.source_id,
                link.destination_id,
                link.resource_id,
                link.priority,
                target_tick
            )
            job.link_id = link.id
            state.jobs[job.id] = job
            state.events.append(SimulationEvent.new(
                &"job_created",
                target_tick,
                link.source_id,
                job.id,
                link.resource_id
            ))
            state.next_job_id += 1
            available -= 1
            capacity -= 1
            jobs_to_create -= 1


static func demand_capacity(state: SimulationState, link: LogisticsLinkState) -> int:
    if link == null:
        return 0
    var destination := state.get_building(link.destination_id)
    if destination == null:
        return 0
    var definition := state.catalog.get_building(destination.definition_id)
    if definition == null or definition.role != LogisticsPortDef.ROLE_PRODUCTION:
        return destination.free_capacity()

    var production := state.production_states.get(destination.id) as ProductionState
    if production == null or production.status in [ProductionState.LOCKED, ProductionState.COMPLETED]:
        return 0
    var recipe := state.catalog.get_recipe(production.recipe_id)
    if recipe == null:
        return 0
    var amount_per_cycle := recipe.input_amount(link.resource_id)
    if amount_per_cycle <= 0:
        return 0
    if recipe.result_code == &"hammer_struck":
        var boiler := state.production_states.get(production.linked_building_id) as ProductionState
        if boiler == null or boiler.heat_level < 5:
            return 0

    var target := amount_per_cycle * recipe.input_buffer_cycles
    var missing := target - destination.get_amount(link.resource_id) - destination.get_incoming_reserved(link.resource_id)
    return mini(maxi(missing, 0), destination.free_capacity())


func _link_precedes(left: LogisticsLinkState, right: LogisticsLinkState) -> bool:
    return left.id < right.id


func _worker_count(state: SimulationState, link_id: int) -> int:
    var count := 0
    for value: Variant in state.workers.values():
        if (value as WorkerState).link_id == link_id:
            count += 1
    return count


func _job_count(state: SimulationState, link_id: int) -> int:
    var count := 0
    for value: Variant in state.jobs.values():
        if (value as DeliveryJob).link_id == link_id:
            count += 1
    return count
