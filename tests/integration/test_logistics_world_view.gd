extends TestCase


func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)

    var world := instance.get_node("World/LogisticsWorldView") as LogisticsWorldView
    assert_eq(world.get_worker_view_count(), 6, "создаются шесть WorkerView")
    assert_eq(world.get_building_view_count(), 8, "создаются восемь BuildingView полного сценария")
    _assert_segment_interpolation()
    var before := world.get_worker_visual_position(0)
    var controller := instance.get_node("SimulationController") as SimulationController
    controller.set_process(false)
    for _index in 80:
        controller.advance_frame(0.1)
    assert_true(before != world.get_worker_visual_position(0), "worker визуально движется")

    instance.free()
    return finish()


func _assert_segment_interpolation() -> void:
    var layout := HexLayout.new(32.0)
    var worker := WorkerState.new(1, HexCoord.new(0, 0))
    worker.segment_target = HexCoord.new(1, 0)
    worker.segment_duration = 4
    var view := WorkerView.new()
    view.configure(worker, layout)
    worker.segment_progress = 1
    view.capture_tick(worker, layout)
    view.set_interpolation(0.5)
    var expected := layout.coord_to_pixel(worker.coord).lerp(
        layout.coord_to_pixel(worker.segment_target),
        0.125
    )
    assert_near(
        view.get_visual_position().x,
        expected.x,
        0.001,
        "позиция x интерполируется внутри сегмента"
    )
    assert_near(
        view.get_visual_position().y,
        expected.y,
        0.001,
        "позиция y интерполируется внутри сегмента"
    )
    view.free()
