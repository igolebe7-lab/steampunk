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
    assert_eq(instance.get_node("UI/Margin/VBox/Title").text, "Паровая логистика", "заголовок должен быть локализован")
    assert_eq(instance.get_node("UI/Margin/VBox/Status").text, "Выберите гекс", "статус должен быть локализован")
    instance.free()
    return finish()
