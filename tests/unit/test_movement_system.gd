extends TestCase


func run() -> Array[String]:
    var state := LogisticsTestFactory.two_workers_same_target()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_eq(state.cell_reservations.size(), 1, "клетка имеет одну reservation")
    assert_eq(state.cell_reservations.values()[0], 1, "при равном ожидании выигрывает меньший ID")
    assert_eq(state.get_worker(2).wait_reason, &"cell_reserved", "проигравший объясняет ожидание")
    return finish()
