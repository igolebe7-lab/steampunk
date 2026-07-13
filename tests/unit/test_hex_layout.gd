extends TestCase


func run() -> Array[String]:
    var layout := HexLayout.new(32.0, Vector2(10.0, 20.0))
    var coord := HexCoord.new(4, 7)
    var pixel := layout.coord_to_pixel(coord)
    var restored := layout.pixel_to_coord(pixel)

    assert_true(restored.equals(coord), "центр гекса должен преобразовываться обратно в ту же координату")
    assert_near(layout.coord_to_pixel(HexCoord.new(1, 0)).x, 58.0, 0.001, "шаг flat-top по q должен быть 1.5 радиуса")
    assert_near(layout.coord_to_pixel(HexCoord.new(0, 0)).y, 20.0, 0.001, "origin должен смещать центр нулевого гекса")

    var corners := layout.polygon_corners(HexCoord.new(0, 0))
    assert_eq(corners.size(), 6, "полигон гекса должен иметь шесть вершин")
    assert_near(corners[0].distance_to(Vector2(10.0, 20.0)), 32.0, 0.001, "вершины должны находиться на заданном радиусе")

    for q in range(-3, 4):
        for r in range(-3, 4):
            var sample := HexCoord.new(q, r)
            assert_true(
                layout.pixel_to_coord(layout.coord_to_pixel(sample)).equals(sample),
                "round-trip должен работать для %s" % sample.key()
            )
    return finish()
