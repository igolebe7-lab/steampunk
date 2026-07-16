class_name UtilityNetworkSystem
extends RefCounted

const WATER := &"water"
const DELIVERY_INTERVAL_TICKS := 20


func run(state: SimulationState, target_tick: int) -> void:
    if state.utility_network.resolved_topology_revision != state.utility_network.topology_revision:
        _rebuild_components(state)
    if target_tick % DELIVERY_INTERVAL_TICKS != 0:
        return

    for component_id: StringName in _component_ids(state):
        var outputs := _component_buildings(state, component_id, UtilityPortDef.DIRECTION_OUTPUT, WATER)
        var inputs := _component_buildings(state, component_id, UtilityPortDef.DIRECTION_INPUT, WATER)
        for output_id: int in outputs:
            var destination := _first_available_destination(state, inputs)
            if destination == null:
                break
            if not destination.add_amount(WATER, 1):
                continue
            state.generated_totals[WATER] = (state.generated_totals.get(WATER, 0) as int) + 1
            state.utility_network.pipe_water_delivered += 1
            state.telemetry_window.cumulative_pipe_water_delivered += 1
            var event := SimulationEvent.new(&"pipe_water_delivered", target_tick, output_id, 0, WATER)
            event.destination_id = destination.id
            state.events.append(event)


func _rebuild_components(state: SimulationState) -> void:
    var keys := state.utility_network.segments.keys()
    keys.sort()
    var visited: Dictionary = {}
    for key_value: Variant in keys:
        var start_key := key_value as StringName
        if visited.has(start_key):
            continue
        var component_keys: Array[StringName] = []
        var pending: Array[StringName] = [start_key]
        visited[start_key] = true
        while not pending.is_empty():
            var current_key := pending.pop_front() as StringName
            component_keys.append(current_key)
            var current := state.utility_network.segments[current_key] as UtilitySegmentState
            for neighbor: HexCoord in current.coord.neighbors():
                var neighbor_key := neighbor.key()
                var segment := state.utility_network.segments.get(neighbor_key) as UtilitySegmentState
                if (
                    segment != null
                    and segment.commodity_id == current.commodity_id
                    and not visited.has(neighbor_key)
                ):
                    visited[neighbor_key] = true
                    pending.append(neighbor_key)
        component_keys.sort()
        var component_id: StringName = component_keys.front() as StringName
        for component_key: StringName in component_keys:
            (state.utility_network.segments[component_key] as UtilitySegmentState).component_id = component_id
    state.utility_network.resolved_topology_revision = state.utility_network.topology_revision


func _component_ids(state: SimulationState) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in state.utility_network.segments.values():
        var component_id := (value as UtilitySegmentState).component_id
        if not component_id.is_empty() and not result.has(component_id):
            result.append(component_id)
    result.sort()
    return result


func _component_buildings(
    state: SimulationState,
    component_id: StringName,
    direction: StringName,
    commodity_id: StringName
) -> Array[int]:
    var result: Array[int] = []
    var keys := state.utility_network.segments.keys()
    keys.sort()
    for key_value: Variant in keys:
        var segment := state.utility_network.segments[key_value] as UtilitySegmentState
        if segment.component_id != component_id or segment.commodity_id != commodity_id:
            continue
        for neighbor: HexCoord in segment.coord.neighbors():
            var building_id := state.occupied_cells.get(neighbor.key(), 0) as int
            if building_id <= 0 or result.has(building_id):
                continue
            var building := state.get_building(building_id)
            var definition := state.catalog.get_building(building.definition_id)
            if definition != null and _has_port(definition, direction, commodity_id):
                result.append(building_id)
    result.sort()
    return result


func _has_port(definition: BuildingDef, direction: StringName, commodity_id: StringName) -> bool:
    for port: UtilityPortDef in definition.utility_ports:
        if port.direction == direction and port.commodity_id == commodity_id:
            return true
    return false


func _first_available_destination(state: SimulationState, ids: Array[int]) -> BuildingState:
    for building_id: int in ids:
        var building := state.get_building(building_id)
        if building != null and JobSystem.production_resource_capacity(state, building, WATER) > 0:
            return building
    return null
