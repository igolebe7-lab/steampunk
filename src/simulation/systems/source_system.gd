class_name SourceSystem
extends RefCounted


func run(state: SimulationState, target_tick: int) -> void:
    var building_ids: Array[int] = []
    for building_id: Variant in state.buildings.keys():
        building_ids.append(building_id as int)
    building_ids.sort()

    for building_id: int in building_ids:
        var building := state.get_building(building_id)
        var definition := state.catalog.get_building(building.definition_id)
        if definition == null or not definition.is_source():
            continue

        building.source_progress_ticks += 1
        if building.source_progress_ticks < definition.source_interval_ticks:
            continue

        var resource_id := definition.source_resource_id
        if (
            building.get_amount(resource_id) >= definition.source_capacity
            or building.free_capacity() <= 0
        ):
            building.source_progress_ticks = definition.source_interval_ticks
            continue

        if building.add_amount(resource_id, 1):
            building.source_progress_ticks -= definition.source_interval_ticks
            var generated: int = state.generated_totals.get(resource_id, 0) as int
            state.generated_totals[resource_id] = generated + 1
            state.events.append(SimulationEvent.new(
                &"resource_generated",
                target_tick,
                building_id,
                0,
                resource_id
            ))
