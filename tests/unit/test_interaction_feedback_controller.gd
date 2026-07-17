extends TestCase


func run() -> Array[String]:
    _assert_hover_does_not_mutate_state()
    _assert_road_and_depot_reasons()
    _assert_link_targets_follow_compatibility()
    _assert_pipe_guidance_and_confirmation()
    return finish()


func _assert_hover_does_not_mutate_state() -> void:
    var state := Stage5TestFactory.production_state()
    var before := StateHasher.new().hash_state(state)
    var tools := ToolController.new()
    var controller := InteractionFeedbackController.new()

    var feedback := controller.evaluate(
        state,
        tools,
        &"building",
        state.main_warehouse_id,
        state.get_building(state.main_warehouse_id).coord,
        &"hex",
        0,
        HexCoord.new(2, 2)
    )

    assert_eq(feedback.hover_id, state.main_warehouse_id, "feedback сохраняет hover отдельно")
    assert_eq(feedback.selected_kind, &"hex", "существующий выбор не меняется от hover")
    assert_eq(StateHasher.new().hash_state(state), before, "расчёт feedback не меняет симуляцию")


func _assert_road_and_depot_reasons() -> void:
    var state := Stage5TestFactory.production_state()
    state.get_building(state.main_warehouse_id).inventories[&"wood"] = 100
    var controller := InteractionFeedbackController.new()
    var tools := ToolController.new()
    tools.begin_road()
    var occupied := state.get_building(state.main_warehouse_id).coord

    var road := controller.evaluate(state, tools, &"building", state.main_warehouse_id, occupied)

    assert_eq(road.target_state, InteractionFeedbackState.INVALID, "занятая клетка дороги недопустима")
    assert_eq(road.reason_code, &"cell_occupied", "feedback объясняет занятость клетки")

    tools.begin_depot()
    var depot_coord := HexCoord.new(7, 4)
    var without_road := controller.evaluate(state, tools, &"hex", 0, depot_coord)
    assert_eq(without_road.reason_code, &"depot_not_adjacent_to_road", "склад требует соседнюю дорогу")
    state.map_state.get_cell(depot_coord.neighbor(0)).road_level = RoadLevelDef.LEVEL_PATH
    var with_road := controller.evaluate(state, tools, &"hex", 0, depot_coord)
    assert_eq(with_road.target_state, InteractionFeedbackState.VALID, "соседняя дорога делает клетку склада допустимой")


func _assert_link_targets_follow_compatibility() -> void:
    var state := Stage5TestFactory.production_state()
    var controller := InteractionFeedbackController.new()
    var tools := ToolController.new()
    tools.begin_link()

    var origins := controller.evaluate(state, tools, &"", 0, null)
    var wood_source := Stage5TestFactory.building(state, &"wood_source")
    assert_true(origins.highlight_entity_ids.has(wood_source.id), "источник древесины подсвечен как начало связи")

    tools.handle_selection(&"building", wood_source.id, wood_source.coord)
    var destinations := controller.evaluate(state, tools, &"", 0, null)
    assert_true(destinations.highlight_entity_ids.has(state.main_warehouse_id), "совместимый главный склад подсвечен как назначение")


func _assert_pipe_guidance_and_confirmation() -> void:
    var state := Stage5TestFactory.production_state()
    var controller := InteractionFeedbackController.new()
    var tools := ToolController.new()
    tools.begin_pipe_build()
    var path := Stage5TestFactory.full_pipe_path()

    var start := controller.evaluate(state, tools, &"", 0, null)
    assert_true(_has_coord(start.highlight_coords, path[0]), "стартовая клетка рядом с насосной подсвечена")
    assert_true(not start.can_confirm, "пустой путь нельзя подтвердить")

    for coord: HexCoord in path:
        tools.handle_selection(&"hex", 0, coord)
    var completed := controller.evaluate(state, tools, &"hex", 0, path[-1])

    assert_true(completed.can_confirm, "полный путь от насосной к котлу можно подтвердить")
    assert_eq(completed.cost, 2, "feedback показывает авторитетную стоимость трубы")
    assert_eq(completed.preview_coords.size(), path.size(), "выбранный путь остаётся в preview")


func _has_coord(values: Array[HexCoord], expected: HexCoord) -> bool:
    for value: HexCoord in values:
        if value.equals(expected):
            return true
    return false
