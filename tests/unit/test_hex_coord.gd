extends TestCase


func run() -> Array[String]:
    var origin := HexCoord.new(0, 0)
    var neighbors := origin.neighbors()

    assert_eq(neighbors.size(), 6, "у гекса должно быть шесть направлений")
    assert_true(neighbors[0].equals(HexCoord.new(1, 0)), "направление 0 должно вести на восток")
    assert_true(neighbors[2].equals(HexCoord.new(0, -1)), "направление 2 должно вести на северо-запад")
    assert_eq(origin.s, 0, "кубическая координата s начала должна быть нулевой")
    assert_eq(HexCoord.new(3, -2).s, -1, "s должна вычисляться как -q-r")
    assert_eq(origin.distance_to(HexCoord.new(3, -2)), 3, "расстояние должно быть кубическим")
    assert_eq(HexCoord.new(-4, 7).key(), &"-4:7", "ключ должен быть стабильным")
    return finish()
