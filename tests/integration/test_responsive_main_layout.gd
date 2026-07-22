extends TestCase


const REQUIRED_PATHS := [
    "UI/SafeArea/Shell/TopBar",
    "UI/SafeArea/Shell/Body/LeftPanel",
    "UI/SafeArea/Shell/Body/Center/WorldSpace",
    "UI/SafeArea/Shell/Body/Center/ContextPanel",
    "UI/SafeArea/Shell/Body/Center/BottomBar",
    "UI/SafeArea/Shell/Body/RightPanel",
    "UI/SafeArea/Shell/Body/Center/BottomBar/Margin/Tools/PipeBuild",
    "UI/SafeArea/Shell/Body/Center/ContextPanel/Margin/HBox/Actions/Confirm",
    "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomOutButton",
    "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomLabel",
    "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomInButton",
    "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomFitButton",
]


func run() -> Array[String]:
    var tree := Engine.get_main_loop() as SceneTree
    var previous_size := tree.root.size
    tree.root.size = Vector2i(1920, 1080)
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    tree.root.add_child(instance)
    var safe_area := instance.get_node("UI/SafeArea") as MarginContainer
    _sort_containers(safe_area)
    instance.call("_refresh_responsive_layout", true)
    var missing := false
    for path: String in REQUIRED_PATHS:
        if not instance.has_node(path):
            missing = true
            assert_true(false, "адаптивный узел существует: %s" % path)
    if missing:
        instance.free()
        return finish()

    var world_space := instance.get_node(
        "UI/SafeArea/Shell/Body/Center/WorldSpace"
    ) as Control
    var context := instance.get_node(
        "UI/SafeArea/Shell/Body/Center/ContextPanel"
    ) as Control
    var tools := instance.get_node(
        "UI/SafeArea/Shell/Body/Center/BottomBar"
    ) as Control
    var inspector := instance.get_node(
        "UI/SafeArea/Shell/Body/RightPanel"
    ) as Control

    assert_true(world_space.size.x >= 1100.0, "мир имеет полноразмерную ширину")
    assert_true(
        world_space.size.y >= 720.0,
        "мир имеет полноразмерную высоту: world=%s center=%s body=%s" % [
            world_space.size,
            (instance.get_node("UI/SafeArea/Shell/Body/Center") as Control).size,
            (instance.get_node("UI/SafeArea/Shell/Body") as Control).size,
        ]
    )
    assert_true(
        not context.get_global_rect().intersects(tools.get_global_rect()),
        "подсказка не перекрывает инструменты"
    )
    assert_true(
        not context.get_global_rect().intersects(inspector.get_global_rect()),
        "подсказка не перекрывает инспектор"
    )
    assert_true(
        not tools.get_global_rect().intersects(inspector.get_global_rect()),
        "инструменты не перекрывают инспектор"
    )
    var snapshot := instance.get_layout_snapshot() as Dictionary
    assert_true(
        (snapshot.get(&"revision", 0) as int) >= 1,
        "главная сцена применяет safe area камеры"
    )
    assert_eq(
        instance.get_window().min_size,
        Vector2i(1280, 720),
        "окно запрещает физический размер меньше 1280×720"
    )
    var camera := instance.get_node("CameraController") as CameraController
    var zoom_in := instance.get_node(
        "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomInButton"
    ) as Button
    var zoom_label := instance.get_node(
        "UI/SafeArea/Shell/TopBar/Margin/HBox/ZoomControls/ZoomLabel"
    ) as Label
    var before_zoom := camera.zoom.x
    zoom_in.pressed.emit()
    assert_true(camera.zoom.x > before_zoom, "видимая кнопка приближает камеру")
    assert_eq(zoom_label.text, "%d%%" % camera.get_zoom_percent(), "HUD показывает текущий масштаб")
    instance.free()
    tree.root.size = previous_size
    return finish()


func _sort_containers(node: Node) -> void:
    if node is Container:
        node.notification(Container.NOTIFICATION_SORT_CHILDREN)
    for child: Node in node.get_children():
        _sort_containers(child)
