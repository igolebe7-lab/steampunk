extends TestCase


func run() -> Array[String]:
    var space := Control.new()
    space.position = Vector2(248, 96)
    space.size = Vector2(1300, 760)
    var camera := CameraController.new()
    camera.configure_bounds(Rect2(Vector2(80, 80), Vector2(520, 520)))
    var layout := ResponsiveLayoutController.new()
    layout.configure(space, camera)

    assert_true(
        layout.refresh(Vector2(1920, 1080), true),
        "первая геометрия применяется"
    )
    assert_true(
        not layout.refresh(Vector2(1920, 1080)),
        "та же геометрия не пересчитывается"
    )
    assert_eq(
        layout.snapshot()[&"revision"],
        1,
        "revision меняется только один раз"
    )
    assert_eq(
        camera.get_safe_screen_rect(),
        Rect2(Vector2(248, 96), Vector2(1300, 760)),
        "камера получает мировую область"
    )

    space.size = Vector2(1310, 760)
    assert_true(
        layout.refresh(Vector2(1920, 1080)),
        "изменённая геометрия применяется"
    )
    assert_eq(layout.snapshot()[&"revision"], 2, "resize увеличивает revision")
    camera.free()
    space.free()
    return finish()
