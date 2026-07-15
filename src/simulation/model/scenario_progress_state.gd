class_name ScenarioProgressState
extends RefCounted

const INACTIVE := &"inactive"
const OBSERVATION := &"observation"
const SITE_PREPARATION := &"site_preparation"
const BOILER_SUPPLY := &"boiler_supply"
const WARMING := &"warming"
const FIRST_STRIKE := &"first_strike"
const COMPLETED := &"completed"

var enabled: bool = false
var phase: StringName = INACTIVE
var observation_ticks: int = 900
var phase_entry_tick: int = 0
var active_start_tick: int = 0
var completed_tick: int = 0
var boiler_id: int = 0
var hammer_id: int = 0
var pump_station_id: int = 0
var hammer_strikes: int = 0
var baseline_metrics: Dictionary = {}
var final_metrics: Dictionary = {}


func configure(p_observation_ticks: int, p_boiler_id: int, p_hammer_id: int, p_pump_station_id: int) -> void:
    enabled = true
    phase = OBSERVATION
    observation_ticks = maxi(p_observation_ticks, 0)
    boiler_id = p_boiler_id
    hammer_id = p_hammer_id
    pump_station_id = p_pump_station_id
