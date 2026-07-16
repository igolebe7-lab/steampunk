class_name ResultPanelController
extends RefCounted

var _panel: Control
var _title: Label
var _metrics: RichTextLabel
var _continue: Button


func configure(panel: Control, title: Label, metrics: RichTextLabel, continue_button: Button) -> void:
    _panel = panel
    _title = title
    _metrics = metrics
    _continue = continue_button
    _panel.visible = false
    _title.text = tr(&"ui.result.title")
    _continue.text = tr(&"ui.result.continue")
    _continue.pressed.connect(func() -> void: _panel.visible = false)


func refresh(state: SimulationState) -> void:
    if state == null or state.scenario_progress.phase != ScenarioProgressState.COMPLETED:
        return
    _title.text = tr(&"ui.result.title")
    _metrics.text = build_text(state.scenario_progress.final_metrics)
    _panel.visible = true


func build_text(values: Dictionary) -> String:
    var manual := values.get(&"manual_water", 0) as int
    var pipe := values.get(&"pipe_water", 0) as int
    var ratio := float(pipe) / float(maxi(manual, 1))
    return tr(&"ui.result.metrics").format({
        "active": values.get(&"active_ticks", 0),
        "jobs": values.get(&"completed_jobs", 0),
        "manual": manual,
        "pipe": pipe,
        "ratio": "%.1f" % ratio,
    })
