extends TestCase


func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    assert_eq(instance.get_playtest_recorder(), null, "обычная игра не создаёт recorder")

    var runner: SimulationRunner = instance.get_runner()
    var hash_before := StateHasher.new().hash_state(runner.state)
    var session := PlaytestSession.new("PT-INT", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, func() -> int: return runner.state.tick * 100)
    var storage := PlaytestStorage.new(
        "user://playtest-tests/PT-INT-%d" % Time.get_ticks_usec()
    )
    instance.configure_playtest_for_test(recorder, storage)
    assert_eq(
        StateHasher.new().hash_state(runner.state),
        hash_before,
        "подключение не меняет состояние"
    )

    var main_warehouse := runner.state.get_building(runner.state.main_warehouse_id)
    var main_position := HexLayout.new(32.0, Vector2.ZERO).coord_to_pixel(
        main_warehouse.coord
    )
    instance.call("_on_world_position_selected", main_position)
    instance.get_hud_controller().set_layer_visible(&"routes", true)
    instance.get_hud_controller().set_speed_multiplier(2)
    instance.call("_begin_road")
    instance.get_hud_controller().submit_intent({
        &"code": &"link_settings",
        &"link_id": 1,
        &"quota": 2,
        &"priority": 3,
        &"dispatch_enabled": true,
    })

    main_warehouse.inventories[&"iron"] = 10
    main_warehouse.inventories[&"wood"] = 100
    var interaction_hash := StateHasher.new().hash_state(runner.state)
    instance.call("_begin_pipe_build")
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    for coord: HexCoord in Stage5TestFactory.full_pipe_path():
        var position := layout.coord_to_pixel(coord)
        instance.call("_on_world_position_hovered", position)
        instance.call("_on_world_position_selected", position)
    var confirm := instance.get_node("UI/ContextPanel/Margin/HBox/Actions/Confirm") as Button
    assert_true(confirm.visible, "составной инструмент показывает отдельное подтверждение")
    assert_true(not confirm.disabled, "полный маршрут включает подтверждение")
    assert_true(confirm.text.contains("2"), "подтверждение показывает стоимость трубы")
    assert_eq(
        StateHasher.new().hash_state(runner.state),
        interaction_hash,
        "hover и выбор preview не меняют симуляцию"
    )
    confirm.pressed.emit()
    assert_eq(
        runner.state.utility_network.segments.size(),
        Stage5TestFactory.full_pipe_path().size(),
        "подтверждение строит показанный маршрут"
    )
    assert_true(
        (instance.get_node("UI/BottomBar/Margin/Tools/Inspect") as Button).button_pressed,
        "успех возвращает визуально активный осмотр"
    )

    instance.call("_begin_road")
    var road_button := instance.get_node("UI/BottomBar/Margin/Tools/Road") as Button
    assert_true(road_button.button_pressed, "кнопка дороги показывает активный инструмент")
    var road_coord := HexCoord.new(8, 4)
    var road_position := layout.coord_to_pixel(road_coord)
    instance.call("_on_world_position_hovered", road_position)
    instance.call("_on_world_position_selected", road_position)
    var grid := instance.get_node("World/HexGridView") as HexGridView
    assert_eq(grid.get_cached_road_mask(road_coord), 0, "одиночная дорога не рисует шесть ложных ветвей")
    var cancel := instance.get_node("UI/ContextPanel/Margin/HBox/Actions/Cancel") as Button
    assert_true(cancel.visible, "активный инструмент показывает явную отмену")
    cancel.pressed.emit()
    assert_true(
        (instance.get_node("UI/BottomBar/Margin/Tools/Inspect") as Button).button_pressed,
        "отмена возвращает осмотр"
    )

    var codes: Array[String] = []
    for entry: PlaytestEntry in session.entries:
        codes.append(String(entry.code))
    assert_true(codes.has("selection"), "выбор объекта записан")
    assert_true(codes.has("layer_visibility"), "слой записан")
    assert_true(codes.has("speed"), "скорость записана")
    assert_true(codes.has("road"), "инструмент записан")
    assert_true(codes.has("link_settings"), "результат команды записан")
    instance.free()
    return finish()
