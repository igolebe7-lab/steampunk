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
