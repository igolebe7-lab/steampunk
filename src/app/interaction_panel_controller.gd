class_name InteractionPanelController
extends RefCounted

signal confirm_requested
signal cancel_requested

var _title: Label
var _hint: Label
var _target: Label
var _confirm: Button
var _cancel: Button
var _tool_buttons: Dictionary = {}


func configure(
    title: Label,
    hint: Label,
    target: Label,
    confirm: Button,
    cancel: Button,
    tool_buttons: Dictionary
) -> void:
    _title = title
    _hint = hint
    _target = target
    _confirm = confirm
    _cancel = cancel
    _tool_buttons = tool_buttons.duplicate()
    if not _confirm.pressed.is_connected(_on_confirm_pressed):
        _confirm.pressed.connect(_on_confirm_pressed)
    if not _cancel.pressed.is_connected(_on_cancel_pressed):
        _cancel.pressed.connect(_on_cancel_pressed)
    for key: Variant in _tool_buttons.keys():
        var button := _tool_buttons[key] as Button
        if button == null:
            continue
        button.toggle_mode = true
        button.tooltip_text = tr(_tooltip_key(key as StringName))


func present(feedback: InteractionFeedbackState) -> void:
    if feedback == null or _title == null:
        return
    _title.text = tr(StringName("ui.mode.%s" % feedback.mode))
    _hint.text = tr(feedback.hint_key)
    _target.text = _target_text(feedback)
    var is_compound := feedback.mode in [
        ToolController.PIPE_BUILD,
        ToolController.PIPE_REMOVE,
    ]
    _confirm.visible = is_compound
    _confirm.disabled = not feedback.can_confirm
    _confirm.text = (
        tr(&"ui.action.confirm_cost").format({"cost": feedback.cost})
        if feedback.cost > 0
        else tr(&"ui.action.confirm")
    )
    _cancel.visible = feedback.can_cancel
    _cancel.text = tr(&"ui.action.cancel")
    var active_mode := (
        ToolController.LINK_ORIGIN
        if feedback.mode == ToolController.LINK_DESTINATION
        else feedback.mode
    )
    for key: Variant in _tool_buttons.keys():
        var button := _tool_buttons[key] as Button
        if button != null:
            button.set_pressed_no_signal((key as StringName) == active_mode)


func _target_text(feedback: InteractionFeedbackState) -> String:
    if not feedback.reason_code.is_empty():
        var reason_key := StringName("command.%s" % feedback.reason_code)
        var localized := tr(reason_key)
        return tr(&"ui.target.invalid").format({
            "reason": tr(&"command.unknown") if localized == String(reason_key) else localized,
        })
    if feedback.hover_kind.is_empty():
        return ""
    var kind_key := StringName("ui.target_kind.%s" % feedback.hover_kind)
    var kind := tr(kind_key)
    var template := (
        tr(&"ui.target.valid")
        if feedback.target_state == InteractionFeedbackState.VALID
        else tr(&"ui.target.hover")
    )
    return template.format({"kind": kind})


func _tooltip_key(mode: StringName) -> StringName:
    return StringName("ui.tooltip.%s" % mode)


func _on_confirm_pressed() -> void:
    confirm_requested.emit()


func _on_cancel_pressed() -> void:
    cancel_requested.emit()
