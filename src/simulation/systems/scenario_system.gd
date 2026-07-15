class_name ScenarioSystem
extends RefCounted


func run(state: SimulationState, target_tick: int) -> void:
    var progress := state.scenario_progress
    if progress == null or not progress.enabled or progress.phase == ScenarioProgressState.COMPLETED:
        return

    var boiler := state.production_states.get(progress.boiler_id) as ProductionState
    var hammer := state.production_states.get(progress.hammer_id) as ProductionState
    if boiler == null or hammer == null:
        return

    match progress.phase:
        ScenarioProgressState.OBSERVATION:
            if target_tick >= progress.observation_ticks:
                progress.baseline_metrics = _metrics(state, target_tick)
                progress.active_start_tick = target_tick
                hammer.status = ProductionState.WAITING_INPUTS
                _transition(state, ScenarioProgressState.SITE_PREPARATION, target_tick)
        ScenarioProgressState.SITE_PREPARATION:
            if hammer.status == ProductionState.COMPLETED:
                boiler.status = ProductionState.WAITING_INPUTS
                _transition(state, ScenarioProgressState.BOILER_SUPPLY, target_tick)
        ScenarioProgressState.BOILER_SUPPLY:
            if boiler.status == ProductionState.RUNNING or boiler.heat_level > 0:
                _transition(state, ScenarioProgressState.WARMING, target_tick)
        ScenarioProgressState.WARMING:
            if boiler.heat_level >= ProductionSystem.MAX_HEAT:
                hammer.recipe_id = &"first_hammer_strike"
                hammer.status = ProductionState.WAITING_INPUTS
                hammer.progress_ticks = 0
                hammer.blocked_reason = &""
                _transition(state, ScenarioProgressState.FIRST_STRIKE, target_tick)
        ScenarioProgressState.FIRST_STRIKE:
            if _has_event(state, &"hammer_struck", progress.hammer_id):
                progress.hammer_strikes += 1
                progress.completed_tick = target_tick
                progress.final_metrics = _metrics(state, target_tick)
                progress.final_metrics[&"active_ticks"] = maxi(target_tick - progress.active_start_tick, 0)
                for key: Variant in [&"manual_water", &"pipe_water", &"completed_jobs"]:
                    progress.final_metrics[key] = (
                        (progress.final_metrics.get(key, 0) as int)
                        - (progress.baseline_metrics.get(key, 0) as int)
                    )
                _transition(state, ScenarioProgressState.COMPLETED, target_tick)


func _transition(state: SimulationState, next_phase: StringName, target_tick: int) -> void:
    state.scenario_progress.phase = next_phase
    state.scenario_progress.phase_entry_tick = target_tick
    var event := SimulationEvent.new(&"scenario_phase_changed", target_tick)
    event.reason = next_phase
    state.events.append(event)


func _metrics(state: SimulationState, target_tick: int) -> Dictionary:
    return {
        &"tick": target_tick,
        &"manual_water": state.utility_network.manual_water_delivered,
        &"pipe_water": state.utility_network.pipe_water_delivered,
        &"completed_jobs": state.telemetry_window.cumulative_completed_jobs,
        &"consumed": state.consumed_totals.duplicate(true),
    }


func _has_event(state: SimulationState, code: StringName, entity_id: int) -> bool:
    for event: SimulationEvent in state.events:
        if event.code == code and event.entity_id == entity_id:
            return true
    return false
