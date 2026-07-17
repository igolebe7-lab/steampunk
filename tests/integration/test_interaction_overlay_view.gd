extends TestCase


func run() -> Array[String]:
    var state := Stage5TestFactory.production_state()
    var layout := HexLayout.new(32.0)
    var overlay := InteractionOverlayView.new()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(overlay)
    overlay.configure(state, layout)
    var feedback := _feedback(state)

    overlay.present(feedback)

    assert_eq(overlay.get_hover_visual_count(), 1, "overlay кэширует одно наведение")
    assert_eq(overlay.get_selection_visual_count(), 1, "overlay кэширует один постоянный выбор")
    assert_eq(overlay.get_target_visual_count(), 2, "overlay кэширует допустимые цели")
    assert_eq(overlay.get_preview_visual_count(), 2, "overlay кэширует маршрут предпросмотра")
    assert_eq(overlay.get_target_state(), InteractionFeedbackState.VALID, "overlay сохраняет семантику допустимости")
    var rebuilds := overlay.get_rebuild_count()

    overlay.present(_feedback(state))

    assert_eq(overlay.get_rebuild_count(), rebuilds, "эквивалентный feedback не перестраивает overlay")
    var invalid := _feedback(state)
    invalid.target_state = InteractionFeedbackState.INVALID
    invalid.reason_code = &"cell_occupied"
    invalid.set_hover(&"hex", 0, HexCoord.new(6, 6))
    overlay.present(invalid)
    assert_eq(overlay.get_target_visual_count(), 3, "недопустимый hover добавляется отдельно от допустимых целей")
    assert_eq(overlay.get_child_count(), 0, "overlay не создаёт Node на каждый гекс")
    overlay.free()
    return finish()


func _feedback(state: SimulationState) -> InteractionFeedbackState:
    var feedback := InteractionFeedbackState.new()
    feedback.mode = ToolController.PIPE_BUILD
    feedback.target_state = InteractionFeedbackState.VALID
    feedback.set_hover(&"hex", 0, HexCoord.new(4, 12))
    var main := state.get_building(state.main_warehouse_id)
    feedback.set_selection(&"building", main.id, main.coord)
    var highlights: Array[HexCoord] = [HexCoord.new(4, 12), HexCoord.new(3, 13)]
    var preview: Array[HexCoord] = [HexCoord.new(4, 12), HexCoord.new(3, 13)]
    feedback.set_highlight_coords(highlights)
    feedback.set_preview_coords(preview)
    return feedback
