extends TestCase


func run() -> Array[String]:
    TranslationServer.set_locale("en")
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    _sort_containers(instance.get_node("UI/SafeArea"))
    _assert_layout(instance)
    _assert_time_and_layers(instance)
    _assert_inspectors_and_commands(instance)
    _assert_management_controls(instance)
    instance.free()
    TranslationServer.set_locale("ru")
    return finish()


func _sort_containers(node: Node) -> void:
    if node is Container:
        node.notification(Container.NOTIFICATION_SORT_CHILDREN)
    for child: Node in node.get_children():
        _sort_containers(child)


func _assert_layout(instance: Node) -> void:
    var top := instance.get_node("UI/SafeArea/Shell/TopBar") as Control
    var left := instance.get_node("UI/SafeArea/Shell/Body/LeftPanel") as Control
    var right := instance.get_node("UI/SafeArea/Shell/Body/RightPanel") as Control
    var bottom := instance.get_node("UI/SafeArea/Shell/Body/Center/BottomBar") as Control
    assert_true(top != null and left != null and right != null and bottom != null, "четыре HUD области существуют")
    assert_true(not top.get_global_rect().intersects(bottom.get_global_rect()), "top и bottom не перекрываются")
    assert_true(not left.get_global_rect().intersects(right.get_global_rect()), "left и right не перекрываются")
    assert_true(instance.has_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/Scroll/Inspector"), "right inspector прокручивается")
    for resource_node in ["Wood", "Iron", "Coal", "Water"]:
        assert_true(
            instance.has_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Resources/%s" % resource_node),
            "верхняя панель показывает ресурс: %s" % resource_node
        )
    for path in [
        "UI/SafeArea/Shell/Body/Center/BottomBar/Margin/Tools/Inspect",
        "UI/SafeArea/Shell/Body/Center/BottomBar/Margin/Tools/Road",
        "UI/SafeArea/Shell/Body/Center/BottomBar/Margin/Tools/Depot",
        "UI/SafeArea/Shell/Body/Center/BottomBar/Margin/Tools/Link",
    ]:
        assert_true(instance.has_node(path), "tool button существует: %s" % path)
    for path in [
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Dispatch",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Apply",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Remove",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Reset",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/DirectMain",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/ApplyDirect",
        "UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/Demolish",
    ]:
        assert_true(instance.has_node(path), "management control существует: %s" % path)


func _assert_time_and_layers(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var simulation := instance.get_node("SimulationController") as SimulationController
    (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Speed4") as Button).pressed.emit()
    simulation.advance_frame(0.1)
    assert_eq(runner.state.tick, 4, "x4 выполняет четыре fixed ticks")
    (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Pause") as Button).pressed.emit()
    simulation.advance_frame(0.5)
    assert_eq(runner.state.tick, 4, "pause из HUD останавливает ticks")
    var routes := instance.get_node("UI/SafeArea/Shell/Body/LeftPanel/Margin/Layers/Routes") as CheckButton
    routes.button_pressed = false
    routes.toggled.emit(false)
    assert_true(not instance.get_diagnostics_view().is_layer_visible(&"routes"), "layer toggle управляет DiagnosticsView")


func _assert_inspectors_and_commands(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var inspector: InspectorController = instance.get_inspector_controller()
    var worker_id := runner.state.workers.keys()[0] as int
    var worker_text := inspector.build_text(runner.state, &"worker", worker_id)
    assert_true(worker_text.contains("Worker"), "worker inspector локализован")
    var main := runner.state.get_building(runner.state.main_warehouse_id)
    main.inventories[&"wood"] = 11
    main.inventories[&"iron"] = 7
    main.inventories[&"coal"] = 5
    main.inventories[&"water"] = 3
    main.outgoing_reserved[&"coal"] = 2
    main.incoming_reserved[&"water"] = 1
    var building_text := inspector.build_text(runner.state, &"building", runner.state.main_warehouse_id)
    assert_true(building_text.contains("Building"), "building inspector локализован")
    for expected in ["Wood: 11", "Iron: 7", "Coal: 5", "Water: 3"]:
        assert_true(building_text.contains(expected), "инспектор показывает состав склада: %s" % expected)
    assert_true(building_text.contains("Reserved to send: 2"), "инспектор отделяет исходящий резерв")
    assert_true(building_text.contains("Expected: 1"), "инспектор отделяет входящий резерв")
    assert_true(
        (
            building_text.find("Stored: 26/100")
            < building_text.find("Wood: 11")
            and building_text.find("Wood: 11") < building_text.find("Iron: 7")
            and building_text.find("Iron: 7") < building_text.find("Coal: 5")
            and building_text.find("Coal: 5") < building_text.find("Water: 3")
            and building_text.find("Water: 3") < building_text.find("Level: 1")
        ),
        "инспектор показывает итог, ресурсы в порядке каталога и только затем настройки"
    )
    var boiler_id := 0
    for value: Variant in runner.state.buildings.values():
        var candidate := value as BuildingState
        if candidate.definition_id == &"boiler":
            boiler_id = candidate.id
            candidate.inventories[&"coal"] = 2
            candidate.inventories[&"water"] = 1
    var boiler_text := inspector.build_text(runner.state, &"building", boiler_id)
    assert_true(
        (
            boiler_text.find("Coal: 2") >= 0
            and boiler_text.find("Coal: 2") < boiler_text.find("Water: 1")
            and not boiler_text.contains("Wood:")
            and not boiler_text.contains("Iron:")
        ),
        "производство показывает только релевантные ресурсы в порядке каталога"
    )
    var pump_id := 0
    for value: Variant in runner.state.buildings.values():
        var candidate := value as BuildingState
        if candidate.definition_id == &"pump_station":
            pump_id = candidate.id
    var pump_text := inspector.build_text(runner.state, &"building", pump_id)
    assert_true(not pump_text.contains("Stored: 0/0"), "насосная без инвентаря не изображается складом")
    runner.state.get_building(boiler_id).inventories.clear()
    LogisticsLinkSystem.new().run(runner.state, Pathfinder.new())
    var link_id := runner.state.logistics_links.keys()[0] as int
    var link_text := inspector.build_text(runner.state, &"link", link_id)
    assert_true(link_text.contains("Link"), "link inspector локализован")

    var hud: HUDController = instance.get_hud_controller()
    hud.refresh(runner.state)
    assert_eq(
        (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Resources/Wood") as Label).text,
        "Wood: 11",
        "HUD показывает дерево главного склада"
    )
    assert_eq(
        (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Resources/Iron") as Label).text,
        "Iron: 7",
        "HUD показывает железо главного склада"
    )
    assert_eq(
        (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Resources/Coal") as Label).text,
        "Coal: 5",
        "HUD показывает уголь главного склада"
    )
    assert_eq(
        (instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Resources/Water") as Label).text,
        "Water: 3",
        "HUD показывает воду главного склада"
    )
    main.inventories.clear()
    main.outgoing_reserved.clear()
    main.incoming_reserved.clear()
    main.inventories[&"wood"] = 20
    runner.state.generated_totals[&"wood"] = (runner.state.generated_totals.get(&"wood", 0) as int) + 20
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
    var quota := instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/QuotaRow/Quota") as SpinBox
    var priority := instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/PriorityRow/Priority") as SpinBox
    var dispatch := instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Dispatch") as CheckButton
    quota.value = 1
    priority.value = 4
    dispatch.button_pressed = false
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Apply") as Button).pressed.emit()
    var link := runner.state.logistics_links.get(link_id) as LogisticsLinkState
    assert_eq(link.priority, 4, "inspector применяет приоритет связи через command runner")
    assert_true(not link.dispatch_enabled, "inspector останавливает dispatch через command runner")
    dispatch.button_pressed = true
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Apply") as Button).pressed.emit()
    assert_true(link.dispatch_enabled, "inspector возобновляет dispatch через command runner")

    var source := runner.state.get_building(link.source_id)
    inspector.show_selection(runner.state, &"building", source.id)
    var direct := instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/DirectMain") as CheckButton
    direct.button_pressed = false
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/ApplyDirect") as Button).pressed.emit()
    assert_true(not source.allows_direct_delivery_to_main, "inspector запрещает прямую доставку через command runner")
    direct.button_pressed = true
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/ApplyDirect") as Button).pressed.emit()
    assert_true(source.allows_direct_delivery_to_main, "inspector разрешает прямую доставку через command runner")

    var managed_link_id := runner.state.logistics_links.keys()[0] as int
    var managed_link := runner.state.logistics_links.get(managed_link_id) as LogisticsLinkState
    inspector.show_selection(runner.state, &"link", managed_link_id)
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Reset") as Button).pressed.emit()
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
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/LinkControls/Remove") as Button).pressed.emit()
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
    (instance.get_node("UI/SafeArea/Shell/Body/RightPanel/Margin/VBox/BuildingControls/Demolish") as Button).pressed.emit()
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
