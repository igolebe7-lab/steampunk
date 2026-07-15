class_name ProductionSystem
extends RefCounted

const MAX_HEAT := 5
const COOLING_INTERVAL_TICKS := 200


func run(state: SimulationState, target_tick: int) -> void:
    var ids: Array[int] = []
    for key: Variant in state.production_states.keys():
        ids.append(key as int)
    ids.sort()

    for building_id: int in ids:
        var production := state.production_states.get(building_id) as ProductionState
        var building := state.get_building(building_id)
        var recipe := state.catalog.get_recipe(production.recipe_id) if production != null else null
        if production == null or building == null or recipe == null:
            continue
        if production.status in [ProductionState.LOCKED, ProductionState.COMPLETED]:
            continue

        var completed_this_tick := false
        if production.status == ProductionState.RUNNING:
            production.progress_ticks += 1
            production.cooling_ticks = 0
            if production.progress_ticks >= recipe.duration_ticks:
                _complete_cycle(state, building, production, recipe, target_tick)
                completed_this_tick = true
            else:
                continue

        if completed_this_tick:
            continue
        if not _can_start(state, building, production, recipe):
            _advance_cooling(state, production, recipe, target_tick)
            continue
        _consume_inputs(state, building, recipe)
        production.status = ProductionState.RUNNING
        production.progress_ticks = 1
        production.cooling_ticks = 0
        production.blocked_reason = &""
        state.events.append(SimulationEvent.new(&"production_started", target_tick, building.id))
        if recipe.duration_ticks <= 1:
            _complete_cycle(state, building, production, recipe, target_tick)


func _can_start(
    state: SimulationState,
    building: BuildingState,
    production: ProductionState,
    recipe: RecipeDef
) -> bool:
    if recipe.result_code == &"hammer_struck":
        var boiler := state.production_states.get(production.linked_building_id) as ProductionState
        if boiler == null or boiler.heat_level < MAX_HEAT:
            production.status = ProductionState.BLOCKED
            production.blocked_reason = &"boiler_not_hot"
            return false
    for index in recipe.input_resource_ids.size():
        var resource_id := recipe.input_resource_ids[index]
        if building.get_amount(resource_id) < recipe.input_amounts[index]:
            production.status = ProductionState.WAITING_INPUTS
            production.blocked_reason = StringName("no_%s" % resource_id)
            return false
    return true


func _consume_inputs(state: SimulationState, building: BuildingState, recipe: RecipeDef) -> void:
    for index in recipe.input_resource_ids.size():
        var resource_id := recipe.input_resource_ids[index]
        var amount := recipe.input_amounts[index]
        building.remove_amount(resource_id, amount)
        state.consumed_totals[resource_id] = (state.consumed_totals.get(resource_id, 0) as int) + amount


func _complete_cycle(
    state: SimulationState,
    building: BuildingState,
    production: ProductionState,
    recipe: RecipeDef,
    target_tick: int
) -> void:
    production.progress_ticks = 0
    production.completed_cycles += 1
    production.cooling_ticks = 0
    production.blocked_reason = &""
    if recipe.result_code == &"boiler_heat":
        production.heat_level = mini(production.heat_level + 1, MAX_HEAT)
        production.status = ProductionState.WAITING_INPUTS
    else:
        production.status = ProductionState.COMPLETED
    var completed := SimulationEvent.new(&"production_completed", target_tick, building.id)
    completed.reason = recipe.result_code
    completed.metric_value = production.completed_cycles
    state.events.append(completed)
    if recipe.result_code == &"hammer_struck":
        state.events.append(SimulationEvent.new(&"hammer_struck", target_tick, building.id))


func _advance_cooling(
    state: SimulationState,
    production: ProductionState,
    recipe: RecipeDef,
    target_tick: int
) -> void:
    if recipe.result_code != &"boiler_heat" or production.heat_level <= 0:
        return
    production.cooling_ticks += 1
    if production.cooling_ticks < COOLING_INTERVAL_TICKS:
        return
    production.cooling_ticks = 0
    production.heat_level = maxi(production.heat_level - 1, 0)
    var event := SimulationEvent.new(&"boiler_cooled", target_tick, production.building_id)
    event.metric_value = production.heat_level
    state.events.append(event)
