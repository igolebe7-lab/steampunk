class_name DiagnosticsSystem
extends RefCounted


func run(state: SimulationState) -> void:
    var selected_code := &""
    var selected_loss := 0
    for code: StringName in DiagnosticReport.SUPPORTED_CODES:
        var measured := state.telemetry_window.loss_ticks(code)
        if measured > selected_loss:
            selected_code = code
            selected_loss = measured
    state.diagnostic_report = DiagnosticReport.new(
        selected_code,
        selected_loss,
        state.telemetry_window.biggest_loss_link(selected_code),
        state.telemetry_window.biggest_loss_cell(selected_code)
    )
