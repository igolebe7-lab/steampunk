extends TestCase


func run() -> Array[String]:
    var queue := CommandQueue.new()
    var first_result := queue.enqueue(
        SimulationCommand.set_building_priority(2, 20, 1, 4),
        0
    )
    assert_true(
        first_result.accepted,
        "будущая команда должна приниматься"
    )
    assert_eq(first_result.command_id, &"2:20", "результат должен содержать стабильный ID команды")
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

    var source_command := SimulationCommand.set_building_priority(4, 40, 1, 1)
    assert_true(queue.enqueue(source_command, 0).accepted, "команда для snapshot должна приниматься")
    source_command._sequence = 1
    source_command._priority = 4
    var snapshotted := queue.take_for_tick(4)
    assert_eq(snapshotted[0].sequence, 40, "очередь должна фиксировать sequence при enqueue")
    assert_eq(snapshotted[0].priority, 1, "очередь должна фиксировать payload при enqueue")
    return finish()
