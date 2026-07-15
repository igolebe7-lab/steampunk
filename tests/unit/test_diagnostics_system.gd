extends TestCase

const REQUIRED_CODES: Array[StringName] = [
    &"no_destination",
    &"destination_full",
    &"source_full",
    &"worker_shortage",
    &"route_conflict",
    &"relay_backlog",
    &"no_path",
]


func run() -> Array[String]:
    _assert_structured_codes_and_biggest_loss()
    _assert_diagnostics_do_not_change_simulation_decisions()
    return finish()


func _assert_structured_codes_and_biggest_loss() -> void:
    for code: StringName in REQUIRED_CODES:
        assert_true(DiagnosticReport.is_supported_code(code), "diagnostic code поддерживается: %s" % code)

    var state := _state()
    state.telemetry_window.append_sample({
        &"tick": 1,
        &"losses": {
            &"no_destination": 2,
            &"destination_full": 3,
            &"source_full": 4,
            &"worker_shortage": 5,
            &"route_conflict": 9,
            &"relay_backlog": 7,
            &"no_path": 6,
        },
        &"loss_links": {&"route_conflict": 12},
        &"loss_cells": {&"route_conflict": &"4:5"},
    })
    DiagnosticsSystem.new().run(state)
    assert_eq(state.diagnostic_report.code, &"route_conflict", "выбирается наибольшая измеренная потеря")
    assert_eq(state.diagnostic_report.loss_ticks, 9, "report содержит измеренный размер потери")
    assert_eq(state.diagnostic_report.link_id, 12, "report содержит структурированный link id")
    assert_eq(state.diagnostic_report.cell_key, &"4:5", "report содержит структурированный cell key")


func _assert_diagnostics_do_not_change_simulation_decisions() -> void:
    var state := _state()
    var building_count := state.buildings.size()
    var worker_count := state.workers.size()
    var job_count := state.jobs.size()
    var next_job_id := state.next_job_id
    state.telemetry_window.append_sample({&"tick": 1, &"losses": {&"worker_shortage": 1}})

    DiagnosticsSystem.new().run(state)

    assert_eq(state.buildings.size(), building_count, "диагностика не меняет здания")
    assert_eq(state.workers.size(), worker_count, "диагностика не меняет работников")
    assert_eq(state.jobs.size(), job_count, "диагностика не меняет очередь job")
    assert_eq(state.next_job_id, next_job_id, "диагностика не влияет на будущие simulation ids")


func _state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return ScenarioLoader.new().load_scenario(scenario).state
