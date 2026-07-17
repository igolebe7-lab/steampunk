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

    assert_true(camera.has_method("pan_by"), "контроллер камеры должен предоставлять проверяемое перемещение")
    if not camera.has_method("pan_by"):
        camera.free()
        return finish()

    camera.pan_by(Vector2(10000, 10000))
    assert_eq(camera.position, Vector2(-40, -20), "позиция камеры не должна накапливаться за верхней левой границей")
    camera.pan_by(Vector2(-10000, -10000))
    assert_eq(camera.position, Vector2(860, 1180), "позиция камеры не должна накапливаться за нижней правой границей")
    camera.free()

    var safe_camera := CameraController.new()
    safe_camera.configure_bounds(Rect2(Vector2(80, 80), Vector2(520, 520)))
    safe_camera.configure_safe_view(
        Rect2(Vector2(248, 96), Vector2(1300, 760)),
        Vector2(1920, 1080),
        true
    )
    var projected := (
        (Vector2(340, 340) - safe_camera.position) * safe_camera.zoom.x
        + Vector2(960, 540)
    )
    assert_near(projected.x, 898.0, 0.01, "центр карты попадает в safe area по X")
    assert_near(projected.y, 476.0, 0.01, "центр карты попадает в safe area по Y")
    assert_eq(
        safe_camera.get_safe_screen_rect(),
        Rect2(Vector2(248, 96), Vector2(1300, 760)),
        "камера сохраняет безопасную экранную область"
    )
    safe_camera.free()
    return finish()
