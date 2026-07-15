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

        var available := source.get_amount(link.resource_id) - source.get_outgoing_reserved(link.resource_id)
        var capacity := destination.free_capacity()
        while available > 0 and capacity > 0:
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


func _link_precedes(left: LogisticsLinkState, right: LogisticsLinkState) -> bool:
    return left.id < right.id
