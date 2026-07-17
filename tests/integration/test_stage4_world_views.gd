extends TestCase


func run() -> Array[String]:
    _assert_road_and_heat_cache()
    _assert_dynamic_world_and_diagnostics()
    _assert_selection_priority()
    _assert_selection_peek_is_non_mutating()
    _assert_tool_state_machine()
    return finish()


func _assert_road_and_heat_cache() -> void:
    var map_state := HexMapState.new(6, 6)
    var coord := HexCoord.new(2, 2)
    map_state.get_cell(coord).road_level = RoadLevelDef.LEVEL_DIRT_ROAD
    var view := HexGridView.new()
    view.configure(map_state, HexLayout.new(32.0))
    assert_eq(view.get_rebuild_count(), 1, "первичная настройка строит геометрический кэш один раз")
    view.capture_tick(map_state)
    assert_eq(view.get_rebuild_count(), 1, "неизменившаяся карта не пересобирает 324 гекса")
    view.set_heat_overlay({coord.key(): 0.75})
    assert_eq(view.get_cached_road_level(coord), RoadLevelDef.LEVEL_DIRT_ROAD, "road level кэшируется для _draw")
    assert_near(view.get_cached_heat(coord), 0.75, 0.001, "heat overlay кэшируется отдельно от simulation state")
    map_state.get_cell(coord).road_level = RoadLevelDef.LEVEL_PATH
    view.capture_tick(map_state)
    assert_eq(view.get_rebuild_count(), 3, "изменение дороги пересобирает кэш после heat overlay")
    assert_near(view.get_cached_heat(coord), 0.75, 0.001, "road refresh не очищает включённый heat layer")
    view.free()


func _assert_dynamic_world_and_diagnostics() -> void:
    var state := _state()
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    var layout := HexLayout.new(32.0)
    var world := LogisticsWorldView.new()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(world)
    world.configure(state, layout)
    var initial_buildings := world.get_building_view_count()

    var definition := state.catalog.get_building(&"transfer_depot")
    var depot := BuildingState.new(state.next_entity_id, definition.id, HexCoord.new(1, 1), 2)
    depot.inventory_capacity = definition.inventory_capacity
    state.buildings[depot.id] = depot
    state.next_entity_id += 1
    world.capture_tick(state)
    assert_eq(world.get_building_view_count(), initial_buildings + 1, "capture_tick динамически добавляет BuildingView")
    assert_true(world.has_building_view(depot.id), "динамический BuildingView доступен по stable id")

    state.buildings.erase(depot.id)
    world.capture_tick(state)
    assert_eq(world.get_building_view_count(), initial_buildings, "capture_tick удаляет исчезнувший BuildingView")

    var worker := state.workers.values()[0] as WorkerState
    worker.route = [worker.coord, worker.coord.neighbor(0)]
    worker.wait_reason = &"cell_reserved"
    var diagnostics := world.get_diagnostics_view()
    diagnostics.capture_tick(state)
    assert_true(diagnostics.get_link_visual_count() > 0, "DiagnosticsView кэширует auto/manual links")
    assert_true(diagnostics.get_route_visual_count() > 0, "DiagnosticsView кэширует worker routes")
    assert_true(diagnostics.get_status_visual_count() > 0, "DiagnosticsView кэширует waiting/blocked status")
    assert_true(diagnostics.get_link_load_visual_count() > 0, "DiagnosticsView кэширует link load")
    diagnostics.set_layer_visible(&"routes", false)
    assert_true(not diagnostics.is_layer_visible(&"routes"), "diagnostic layers переключаются без пересборки simulation state")
    world.free()


func _assert_selection_priority() -> void:
    var controller := SelectionController.new()
    var coord := HexCoord.new(3, 4)
    assert_eq(controller.resolve_hit(9, 7, 5, coord), &"worker", "worker имеет высший selection priority")
    assert_eq(controller.selected_id, 9, "worker id сохраняется")
    assert_eq(controller.resolve_hit(0, 7, 5, coord), &"building", "building выбирается перед link")
    assert_eq(controller.resolve_hit(0, 0, 5, coord), &"link", "link выбирается перед hex")
    assert_eq(controller.resolve_hit(0, 0, 0, coord), &"hex", "hex используется как fallback")
    assert_true(controller.selected_coord.equals(coord), "selection хранит stable hex coord")


func _assert_selection_peek_is_non_mutating() -> void:
    var state := _state()
    var layout := HexLayout.new(32.0)
    var world := LogisticsWorldView.new()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(world)
    world.configure(state, layout)
    var controller := SelectionController.new()
    controller.configure(state, layout, world)
    var selected_coord := HexCoord.new(1, 1)
    controller.resolve_hit(0, 0, 0, selected_coord)
    var main := state.get_building(state.main_warehouse_id)

    var hover: Dictionary = controller.peek_at_local_position(layout.coord_to_pixel(main.coord))

    assert_eq(hover.get(&"kind"), &"building", "peek находит здание с обычным приоритетом")
    assert_eq(hover.get(&"entity_id"), main.id, "peek возвращает stable id здания")
    assert_eq(controller.selected_kind, &"hex", "peek не меняет тип существующего selection")
    assert_true(controller.selected_coord.equals(selected_coord), "peek не меняет координату selection")
    world.free()


func _assert_tool_state_machine() -> void:
    var tools := ToolController.new()
    assert_eq(tools.mode, ToolController.INSPECT, "начальный tool — inspect")
    tools.begin_road()
    assert_eq(tools.handle_selection(&"hex", 0, HexCoord.new(2, 2)).get(&"code"), &"road_cell", "road tool создаёт structured intent")
    tools.begin_depot()
    assert_eq(tools.handle_selection(&"hex", 0, HexCoord.new(3, 2)).get(&"code"), &"depot_cell", "depot tool создаёт structured intent")
    tools.begin_link()
    assert_eq(tools.mode, ToolController.LINK_ORIGIN, "link tool начинает с origin")
    tools.handle_selection(&"building", 2, null)
    assert_eq(tools.mode, ToolController.LINK_DESTINATION, "после origin ожидается destination")
    var intent := tools.handle_selection(&"building", 3, null)
    assert_eq(intent.get(&"code"), &"link_complete", "destination завершает link intent")
    assert_eq(intent.get(&"source_id"), 2, "intent сохраняет origin")
    assert_eq(intent.get(&"destination_id"), 3, "intent сохраняет destination")
    tools.cancel()
    assert_eq(tools.mode, ToolController.INSPECT, "cancel всегда возвращает inspect")

    tools.begin_pipe_build()
    tools.handle_selection(&"hex", 0, HexCoord.new(2, 2))
    tools.handle_selection(&"hex", 0, HexCoord.new(3, 2))
    var pipe_intent: Dictionary = tools.prepare_pipe_intent()
    assert_eq((pipe_intent.get(&"cells", []) as Array).size(), 2, "подготовка intent сохраняет весь путь")
    tools.resolve_pipe_result(false)
    assert_eq(tools.mode, ToolController.PIPE_BUILD, "отказ оставляет режим трубы активным")
    assert_eq(tools.pipe_coords.size(), 2, "отказ сохраняет выбранный маршрут")
    tools.resolve_pipe_result(true)
    assert_eq(tools.mode, ToolController.INSPECT, "успех завершает составной инструмент")
    assert_true(tools.pipe_coords.is_empty(), "успех очищает подтверждённый маршрут")


func _state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return ScenarioLoader.new().load_scenario(scenario).state
