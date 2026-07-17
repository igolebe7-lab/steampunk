extends TestCase


func run() -> Array[String]:
    TranslationServer.set_locale("ru")
    var title := Label.new()
    var hint := Label.new()
    var target := Label.new()
    var confirm := Button.new()
    var cancel := Button.new()
    var inspect := Button.new()
    var pipe := Button.new()
    var controller := InteractionPanelController.new()
    controller.configure(title, hint, target, confirm, cancel, {
        ToolController.INSPECT: inspect,
        ToolController.PIPE_BUILD: pipe,
    })
    var feedback := InteractionFeedbackState.new()
    feedback.mode = ToolController.PIPE_BUILD
    feedback.hint_key = &"ui.hint.pipe_build"
    feedback.target_state = InteractionFeedbackState.INVALID
    feedback.reason_code = &"cell_occupied"
    feedback.cost = 2
    feedback.can_confirm = false
    feedback.can_cancel = true

    controller.present(feedback)

    assert_eq(title.text, "Водопровод", "панель локализует название активного режима")
    assert_true(hint.text.contains("соседн"), "подсказка объясняет управление трубой")
    assert_true(target.text.contains("занята"), "панель показывает локализованную причину недопустимости")
    assert_true(confirm.visible, "подтверждение видно для составного инструмента")
    assert_true(confirm.disabled, "неполный маршрут нельзя подтвердить")
    assert_true(cancel.visible, "активный инструмент можно явно отменить")
    assert_true(pipe.button_pressed, "кнопка активного инструмента остаётся нажатой")
    assert_true(not inspect.button_pressed, "неактивный инструмент не выглядит выбранным")

    feedback.target_state = InteractionFeedbackState.VALID
    feedback.reason_code = &""
    feedback.can_confirm = true
    controller.present(feedback)
    assert_true(not confirm.disabled, "полный маршрут разрешает подтверждение")
    assert_true(confirm.text.contains("2"), "кнопка подтверждения показывает стоимость")

    feedback.mode = ToolController.INSPECT
    feedback.hint_key = &"ui.hint.inspect"
    feedback.can_confirm = false
    feedback.can_cancel = false
    feedback.cost = 0
    controller.present(feedback)
    assert_true(not confirm.visible, "осмотр скрывает подтверждение")
    assert_true(not cancel.visible, "осмотр скрывает отмену")
    assert_true(inspect.button_pressed, "режим осмотра отображается активным")

    title.free()
    hint.free()
    target.free()
    confirm.free()
    cancel.free()
    inspect.free()
    pipe.free()
    return finish()
