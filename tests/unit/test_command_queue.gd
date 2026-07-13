extends TestCase


func run() -> Array[String]:
    var queue := CommandQueue.new()
    assert_true(
        queue.enqueue(SimulationCommand.set_building_priority(2, 20, 1, 4), 0).accepted,
        "будущая команда должна приниматься"
    )
    assert_true(
        queue.enqueue(SimulationCommand.set_building_priority(2, 10, 1, 1), 0).accepted,
        "порядок добавления не должен влиять на sequence"
    )
    var commands := queue.take_for_tick(2)
    assert_eq(commands[0].sequence, 10, "меньший sequence должен выполняться первым")
    assert_eq(commands[1].sequence, 20, "больший sequence должен выполняться вторым")
    assert_eq(
        queue.enqueue(SimulationCommand.set_building_priority(0, 30, 1, 2), 0).code,
        &"past_tick",
        "прошедший тик должен отклоняться"
    )
    assert_true(
        queue.enqueue(SimulationCommand.set_building_priority(3, 7, 1, 2), 0).accepted,
        "первый sequence должен приниматься"
    )
    assert_eq(
        queue.enqueue(SimulationCommand.set_building_priority(3, 7, 1, 3), 0).code,
        &"duplicate_sequence",
        "повтор sequence должен отклоняться"
    )
    return finish()
