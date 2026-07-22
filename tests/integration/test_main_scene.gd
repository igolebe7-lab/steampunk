extends TestCase


func run() -> Array[String]:
    var scene_path := "res://scenes/main.tscn"
    assert_true(ResourceLoader.exists(scene_path), "главная сцена должна существовать")
    if not ResourceLoader.exists(scene_path):
        return finish()

    TranslationServer.set_locale("ru")
    var packed_scene := load(scene_path) as PackedScene
    var instance := packed_scene.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)

    assert_true(instance.has_node("World/HexGridView"), "сцена должна содержать HexGridView")
    assert_eq(instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Title").text, "Паровая логистика", "заголовок должен быть локализован")
    assert_eq(instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Status").text, "Выберите гекс", "статус должен быть локализован")
    instance.free()

    TranslationServer.set_locale("en")
    var english_instance := packed_scene.instantiate()
    tree.root.add_child(english_instance)
    assert_eq(
        english_instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Title").text,
        "Steam Logistics",
        "главная сцена должна уважать выбранную английскую локаль"
    )
    var english_grid: HexGridView = english_instance.get_node("World/HexGridView")
    english_grid.select_at_local_position(HexLayout.new(32.0).coord_to_pixel(HexCoord.new(3, 4)))
    assert_eq(
        english_instance.get_node("UI/SafeArea/Shell/TopBar/Margin/HBox/Status").text,
        "Selected hex: 3, 4",
        "динамический статус выбора должен использовать английскую локаль"
    )
    english_instance.free()
    TranslationServer.set_locale("ru")
    return finish()
