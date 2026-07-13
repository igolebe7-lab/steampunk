extends TestCase


func run() -> Array[String]:
    var map_state := HexMapState.new(18, 18)

    assert_eq(map_state.cell_count(), 324, "карта 18×18 должна содержать 324 гекса")
    assert_true(map_state.contains(HexCoord.new(0, 0)), "левый верхний гекс должен существовать")
    assert_true(map_state.contains(HexCoord.new(17, -8)), "верхний гекс последней staggered-колонки должен существовать")
    assert_true(map_state.contains(HexCoord.new(17, 9)), "нижний гекс последней staggered-колонки должен существовать")
    assert_true(not map_state.contains(HexCoord.new(17, 10)), "гекс ниже последней staggered-колонки должен быть вне карты")
    assert_true(not map_state.contains(HexCoord.new(-1, 0)), "отрицательный q должен быть вне карты")
    assert_true(not map_state.contains(HexCoord.new(18, 0)), "q за правой границей должен быть вне карты")
    assert_eq(map_state.get_neighbors(HexCoord.new(0, 0)).size(), 2, "угловой гекс имеет двух соседей внутри карты")
    assert_eq(map_state.get_neighbors(HexCoord.new(8, 8)).size(), 6, "внутренний гекс имеет шесть соседей")

    assert_true(map_state.set_movement_cost(HexCoord.new(2, 3), 4), "стоимость существующего гекса должна изменяться")
    assert_eq(map_state.get_cell(HexCoord.new(2, 3)).movement_cost, 4, "новая стоимость должна сохраниться")
    assert_true(not map_state.set_movement_cost(HexCoord.new(30, 30), 4), "изменение вне карты должно отклоняться")
    return finish()
