extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    _assert_nearest_destination_and_stable_tie()
    _assert_automatic_link_is_pinned()
    _assert_direct_main_policy()
    return finish()


func _assert_nearest_destination_and_stable_tie() -> void:
    var nearest := LogisticsGraphTestFactory.basic()
    LogisticsLinkSystem.new().run(nearest, Pathfinder.new())
    var source_link := _source_link(nearest, 1)
    assert_true(source_link != null, "автовыбор должен создать связь источника")
    assert_eq(source_link.destination_id, 3, "автовыбор использует минимальную стоимость пути")
    assert_true(source_link.is_automatic, "автовыбор создаёт автоматическую связь")

    var tied := LogisticsGraphTestFactory.basic(false)
    tied.get_building(1)._coord = HexCoord.new(3, 0)
    tied.occupied_cells.clear()
    tied.occupied_cells[tied.get_building(1).coord.key()] = 1
    tied.get_building(2)._coord = HexCoord.new(1, 0)
    tied.occupied_cells[tied.get_building(2).coord.key()] = 2
    LogisticsGraphTestFactory.add_building(tied, 3, &"transfer_depot", HexCoord.new(5, 0))
    LogisticsLinkSystem.new().run(tied, Pathfinder.new())
    assert_eq(_source_link(tied, 1).destination_id, 2, "равная стоимость выбирает меньшую координату")


func _assert_automatic_link_is_pinned() -> void:
    var same_destination := LogisticsGraphTestFactory.basic(false)
    LogisticsLinkSystem.new().run(same_destination, Pathfinder.new())
    var converted := CommandSystem.new().apply(
        same_destination,
        LinkCommand.create(1, 9, 1, 2, WOOD)
    )
    assert_true(converted.accepted, "ручной выбор текущего auto-назначения должен приниматься")
    assert_true(
        not _source_link(same_destination, 1).is_automatic,
        "текущая автоматическая связь должна стать ручной"
    )

    var state := LogisticsGraphTestFactory.basic(false)
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    var original_destination := _source_link(state, 1).destination_id
    LogisticsGraphTestFactory.add_building(state, 3, &"transfer_depot", HexCoord.new(2, 0))
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    assert_eq(
        _source_link(state, 1).destination_id,
        original_destination,
        "валидная автоматическая связь не должна молча переключаться"
    )

    var manual := CommandSystem.new().apply(state, LinkCommand.create(1, 10, 1, 3, WOOD))
    assert_true(manual.accepted, "ручная связь должна заменять автоматическую")
    assert_eq(_source_link(state, 1).destination_id, 3, "ручное назначение должно сохраниться")
    assert_true(not _source_link(state, 1).is_automatic, "ручная связь помечается явно")


func _assert_direct_main_policy() -> void:
    var state := LogisticsGraphTestFactory.basic(false)
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    assert_eq(_source_link(state, 1).destination_id, 2, "без альтернативы выбирается главный склад")
    LogisticsGraphTestFactory.add_building(state, 3, &"transfer_depot", HexCoord.new(3, 0))
    var policy := CommandSystem.new().apply(state, DispatchPolicyCommand.new(1, 20, 1, false))
    assert_true(policy.accepted, "политика прямой доставки должна применяться")
    LogisticsLinkSystem.new().run(state, Pathfinder.new())
    assert_eq(_source_link(state, 1).destination_id, 3, "запрет исключает главный склад из автовыбора")


func _source_link(state: SimulationState, source_id: int) -> LogisticsLinkState:
    for value: Variant in state.logistics_links.values():
        var link := value as LogisticsLinkState
        if link.source_id == source_id and link.resource_id == WOOD and not link.is_closing:
            return link
    return null
