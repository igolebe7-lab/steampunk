class_name JobSystem
extends RefCounted


func run(state: SimulationState, target_tick: int) -> void:
    var flows := state.delivery_flows.duplicate()
    flows.sort_custom(_flow_precedes)

    for flow: DeliveryFlowState in flows:
        var source := state.get_building(flow.source_id)
        var destination := state.get_building(flow.destination_id)
        if source == null or destination == null:
            continue

        var available := source.get_amount(flow.resource_id) - source.get_outgoing_reserved(flow.resource_id)
        var capacity := destination.free_capacity()
        while available > 0 and capacity > 0:
            if not source.reserve_outgoing(flow.resource_id, 1):
                break
            if not destination.reserve_incoming(flow.resource_id, 1):
                source.release_outgoing(flow.resource_id, 1)
                break

            var job := DeliveryJob.new(
                state.next_job_id,
                flow.source_id,
                flow.destination_id,
                flow.resource_id,
                flow.priority,
                target_tick
            )
            state.jobs[job.id] = job
            state.events.append(SimulationEvent.new(
                &"job_created",
                target_tick,
                flow.source_id,
                job.id,
                flow.resource_id
            ))
            state.next_job_id += 1
            available -= 1
            capacity -= 1


func _flow_precedes(left: DeliveryFlowState, right: DeliveryFlowState) -> bool:
    return left.id < right.id
