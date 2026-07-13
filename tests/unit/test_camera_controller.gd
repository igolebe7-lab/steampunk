extends TestCase


func run() -> Array[String]:
    var script_path := "res://src/presentation/world/camera_controller.gd"
    assert_true(ResourceLoader.exists(script_path), "скрипт CameraController должен существовать")
    if not ResourceLoader.exists(script_path):
        return finish()

    var camera: Variant = load(script_path).new()
    camera.set_zoom_factor(9.0)
    assert_eq(camera.zoom, Vector2(2.0, 2.0), "масштаб должен ограничиваться максимумом")
    camera.set_zoom_factor(0.1)
    assert_eq(camera.zoom, Vector2(0.5, 0.5), "масштаб должен ограничиваться минимумом")

    camera.configure_bounds(Rect2(Vector2(-40, -20), Vector2(900, 1200)))
    assert_eq(camera.limit_left, -40, "левая граница должна совпасть с картой")
    assert_eq(camera.limit_bottom, 1180, "нижняя граница должна совпасть с картой")
    assert_eq(camera.position, Vector2(410, 580), "камера должна центрироваться по карте")
    camera.free()
    return finish()
