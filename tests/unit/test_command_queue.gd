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
    assert_true(
        source_command is BuildingPriorityCommand,
        "совместимая команда приоритета должна иметь отдельный тип"
    )
    assert_true(queue.enqueue(source_command, 0).accepted, "команда для snapshot должна приниматься")
    source_command._sequence = 1
    source_command._priority = 4
    var snapshotted := queue.take_for_tick(4)
    assert_eq(snapshotted[0].sequence, 40, "очередь должна фиксировать sequence при enqueue")
    assert_eq(snapshotted[0].priority, 1, "очередь должна фиксировать payload при enqueue")

    var road_command := BuildRoadCommand.new(5, 50, [HexCoord.new(1, 2)])
    assert_true(queue.enqueue(road_command, 0).accepted, "типизированная команда должна приниматься")
    road_command._coords[0]._q = 9
    road_command._coords.append(HexCoord.new(3, 4))
    var road_snapshot := queue.take_for_tick(5)[0]
    assert_true(road_snapshot is BuildRoadCommand, "очередь должна сохранять подкласс команды")
    assert_eq(road_snapshot.coords.size(), 1, "snapshot должен копировать массив координат")
    assert_eq(road_snapshot.coords[0].key(), &"1:2", "snapshot должен глубоко копировать координаты")

    var typed_commands: Array[SimulationCommand] = [
        DepotCommand.place(6, 60, HexCoord.new(2, 3)),
        LinkCommand.create(6, 61, 2, 3, &"wood"),
        LinkSettingsCommand.new(6, 62, 7, 2, 2, false),
        DispatchPolicyCommand.new(6, 63, 2, false),
    ]
    for command in typed_commands:
        assert_true(queue.enqueue(command, 0).accepted, "каждый тип команды должен приниматься")
    var typed_snapshots := queue.take_for_tick(6)
    for index in typed_commands.size():
        assert_true(
            typed_snapshots[index].get_script() == typed_commands[index].get_script(),
            "snapshot должен сохранять конкретный тип команды"
        )
    return finish()
