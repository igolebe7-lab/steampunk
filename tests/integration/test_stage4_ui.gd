extends TestCase


func run() -> Array[String]:
    TranslationServer.set_locale("en")
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    _assert_layout(instance)
    _assert_time_and_layers(instance)
    _assert_inspectors_and_commands(instance)
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
