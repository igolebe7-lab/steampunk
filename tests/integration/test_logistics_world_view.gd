extends TestCase


func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)

    var world := instance.get_node("World/LogisticsWorldView") as LogisticsWorldView
    assert_eq(world.get_worker_view_count(), 6, "создаются шесть WorkerView")
    assert_eq(world.get_building_view_count(), 3, "создаются три BuildingView")
    var before := world.get_worker_visual_position(0)
    var controller := instance.get_node("SimulationController") as SimulationController
    controller.set_process(false)
    for _index in 80:
        controller.advance_frame(0.1)
    assert_true(before != world.get_worker_visual_position(0), "worker визуально движется")

    instance.free()
    return finish()
