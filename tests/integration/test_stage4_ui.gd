extends TestCase


func run() -> Array[String]:
    TranslationServer.set_locale("en")
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    _assert_layout(instance)
    _assert_time_and_layers(instance)
    _assert_inspectors_and_commands(instance)
    _assert_management_controls(instance)
    instance.free()
    TranslationServer.set_locale("ru")
    return finish()


func _assert_layout(instance: Node) -> void:
    var top := instance.get_node("UI/TopBar") as Control
    var left := instance.get_node("UI/LeftPanel") as Control
    var right := instance.get_node("UI/RightPanel") as Control
    var bottom := instance.get_node("UI/BottomBar") as Control
    assert_true(top != null and left != null and right != null and bottom != null, "четыре HUD области существуют")
    assert_true(not top.get_global_rect().intersects(bottom.get_global_rect()), "top и bottom не перекрываются")
    assert_true(not left.get_global_rect().intersects(right.get_global_rect()), "left и right не перекрываются")
    assert_true(instance.has_node("UI/RightPanel/Margin/VBox/Scroll/Inspector"), "right inspector прокручивается")
    for path in [
        "UI/BottomBar/Margin/Tools/Inspect", "UI/BottomBar/Margin/Tools/Road",
        "UI/BottomBar/Margin/Tools/Depot", "UI/BottomBar/Margin/Tools/Link",
    ]:
        assert_true(instance.has_node(path), "tool button существует: %s" % path)
    for path in [
        "UI/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota",
        "UI/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority",
        "UI/RightPanel/Margin/VBox/LinkControls/Dispatch",
        "UI/RightPanel/Margin/VBox/LinkControls/Apply",
        "UI/RightPanel/Margin/VBox/LinkControls/Remove",
        "UI/RightPanel/Margin/VBox/LinkControls/Reset",
        "UI/RightPanel/Margin/VBox/BuildingControls/DirectMain",
        "UI/RightPanel/Margin/VBox/BuildingControls/ApplyDirect",
        "UI/RightPanel/Margin/VBox/BuildingControls/Demolish",
    ]:
        assert_true(instance.has_node(path), "management control существует: %s" % path)


func _assert_time_and_layers(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var simulation := instance.get_node("SimulationController") as SimulationController
    (instance.get_node("UI/TopBar/Margin/HBox/Speed4") as Button).pressed.emit()
    simulation.advance_frame(0.1)
    assert_eq(runner.state.tick, 4, "x4 выполняет четыре fixed ticks")
    (instance.get_node("UI/TopBar/Margin/HBox/Pause") as Button).pressed.emit()
    simulation.advance_frame(0.5)
    assert_eq(runner.state.tick, 4, "pause из HUD останавливает ticks")
    var routes := instance.get_node("UI/LeftPanel/Margin/Layers/Routes") as CheckButton
    routes.button_pressed = false
    routes.toggled.emit(false)
    assert_true(not instance.get_diagnostics_view().is_layer_visible(&"routes"), "layer toggle управляет DiagnosticsView")


func _assert_inspectors_and_commands(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var inspector: InspectorController = instance.get_inspector_controller()
    var worker_id := runner.state.workers.keys()[0] as int
    var worker_text := inspector.build_text(runner.state, &"worker", worker_id)
    assert_true(worker_text.contains("Worker"), "worker inspector локализован")
    var building_text := inspector.build_text(runner.state, &"building", runner.state.main_warehouse_id)
    assert_true(building_text.contains("Building"), "building inspector локализован")
    LogisticsLinkSystem.new().run(runner.state, Pathfinder.new())
    var link_id := runner.state.logistics_links.keys()[0] as int
    var link_text := inspector.build_text(runner.state, &"link", link_id)
    assert_true(link_text.contains("Link"), "link inspector локализован")

    var hud: HUDController = instance.get_hud_controller()
    var main := runner.state.get_building(runner.state.main_warehouse_id)
    main.add_amount(&"wood", 10)
    runner.state.generated_totals[&"wood"] = (runner.state.generated_totals.get(&"wood", 0) as int) + 10
    var coord := HexCoord.new(6, 6)
    var before := runner.state.map_state.get_cell(coord).road_level
    var code := hud.submit_intent({&"code": &"road_cell", &"coord": coord})
    assert_eq(code, &"accepted", "HUDController проводит road command через runner")
    assert_eq(runner.state.map_state.get_cell(coord).road_level, before + 1, "road command применён")
    assert_true(hud.localized_command_message(code) != String(code), "command result локализован")


func _assert_management_controls(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var inspector: InspectorController = instance.get_inspector_controller()
    var link_ids: Array = runner.state.logistics_links.keys()
    link_ids.sort()
    var link_id := link_ids[0] as int
    inspector.show_selection(runner.state, &"link", link_id)
    var quota := instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota") as SpinBox
    var priority := instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority") as SpinBox
    var dispatch := instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/Dispatch") as CheckButton
    quota.value = 1
    priority.value = 4
    dispatch.button_pressed = false
    (instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/Apply") as Button).pressed.emit()
    var link := runner.state.logistics_links.get(link_id) as LogisticsLinkState
    assert_eq(link.priority, 4, "inspector применяет приоритет связи через command runner")
    assert_true(not link.dispatch_enabled, "inspector останавливает dispatch через command runner")
    dispatch.button_pressed = true
    (instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/Apply") as Button).pressed.emit()
    assert_true(link.dispatch_enabled, "inspector возобновляет dispatch через command runner")

    var source := runner.state.get_building(link.source_id)
    inspector.show_selection(runner.state, &"building", source.id)
    var direct := instance.get_node("UI/RightPanel/Margin/VBox/BuildingControls/DirectMain") as CheckButton
    direct.button_pressed = false
    (instance.get_node("UI/RightPanel/Margin/VBox/BuildingControls/ApplyDirect") as Button).pressed.emit()
    assert_true(not source.allows_direct_delivery_to_main, "inspector запрещает прямую доставку через command runner")
    direct.button_pressed = true
    (instance.get_node("UI/RightPanel/Margin/VBox/BuildingControls/ApplyDirect") as Button).pressed.emit()
    assert_true(source.allows_direct_delivery_to_main, "inspector разрешает прямую доставку через command runner")

    var managed_link_id := runner.state.logistics_links.keys()[0] as int
    var managed_link := runner.state.logistics_links.get(managed_link_id) as LogisticsLinkState
    inspector.show_selection(runner.state, &"link", managed_link_id)
    (instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/Reset") as Button).pressed.emit()
    var has_automatic := false
    for value: Variant in runner.state.logistics_links.values():
        var candidate := value as LogisticsLinkState
        has_automatic = has_automatic or (
            candidate.source_id == managed_link.source_id
            and candidate.resource_id == managed_link.resource_id
            and candidate.is_automatic
        )
    assert_true(has_automatic, "reset возвращает автоматическую связь через runner")

    var removable_id := runner.state.logistics_links.keys()[0] as int
    inspector.show_selection(runner.state, &"link", removable_id)
    (instance.get_node("UI/RightPanel/Margin/VBox/LinkControls/Remove") as Button).pressed.emit()
    assert_true(not runner.state.logistics_links.has(removable_id), "remove удаляет выбранную связь через runner")

    var main := runner.state.get_building(runner.state.main_warehouse_id)
    assert_true(main.add_amount(&"wood", 10), "тест пополняет главный склад для размещения депо")
    runner.state.generated_totals[&"wood"] = (runner.state.generated_totals.get(&"wood", 0) as int) + 10
    var depot_coord := _prepare_empty_roadside_coord(runner.state)
    var place_code := (instance.get_hud_controller() as HUDController).submit_intent({
        &"code": &"depot_cell",
        &"coord": depot_coord,
    })
    assert_eq(place_code, &"accepted", "HUD размещает депо через runner")
    var depot_id := 0
    for value: Variant in runner.state.buildings.values():
        var building := value as BuildingState
        if building.definition_id == &"transfer_depot":
            depot_id = building.id
    inspector.show_selection(runner.state, &"building", depot_id)
    (instance.get_node("UI/RightPanel/Margin/VBox/BuildingControls/Demolish") as Button).pressed.emit()
    assert_eq(runner.state.get_building(depot_id), null, "inspector разбирает свободное депо через runner")


func _prepare_empty_roadside_coord(state: SimulationState) -> HexCoord:
    for cell: HexCellState in state.map_state.get_cells():
        if not cell.traversable or state.occupied_cells.has(cell.coord.key()):
            continue
        for neighbor: HexCoord in cell.coord.neighbors():
            if (
                state.map_state.contains(neighbor)
                and state.map_state.get_cell(neighbor).traversable
                and not state.occupied_cells.has(neighbor.key())
            ):
                state.map_state.get_cell(neighbor).road_level = RoadLevelDef.LEVEL_PATH
                return cell.coord
    return null
