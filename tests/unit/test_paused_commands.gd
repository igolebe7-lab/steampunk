extends TestCase


func run() -> Array[String]:
    _assert_flush_applies_without_advancing_time()
    _assert_flush_reconciles_topology_without_running_logistics()
    _assert_paused_command_replay_is_deterministic()
    return finish()


func _assert_flush_applies_without_advancing_time() -> void:
    var runner := _runner()
    assert_true(runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, 4)).accepted, "due command принимается")
    assert_true(runner.enqueue(SimulationCommand.set_building_priority(2, 20, 2, 3)).accepted, "future command принимается")

    var paused_hash := runner.flush_commands()

    assert_eq(runner.state.tick, 0, "flush_commands не продвигает simulation tick")
    assert_eq(runner.state.revision, 1, "command transaction увеличивает revision один раз")
    assert_eq(runner.state.get_building(1).priority, 4, "due command применяется на паузе")
    assert_true(runner.state.get_building(2).priority != 3, "future command остаётся в очереди")
    assert_eq(paused_hash.length(), 64, "flush_commands возвращает deterministic hash")
    assert_true(InvariantChecker.new().check(runner.state).is_empty(), "flush_commands проверяет корректное состояние")

    runner.step()
    assert_eq(runner.state.tick, 1, "следующий обычный step продвигает ровно один tick")
    assert_eq(runner.state.revision, 1, "step без due commands не меняет revision")
    runner.flush_commands()
    assert_eq(runner.state.tick, 1, "вторая paused transaction сохраняет текущий tick")
    assert_eq(runner.state.revision, 2, "следующий due batch создаёт новую revision")
    assert_eq(runner.state.get_building(2).priority, 3, "команда следующего tick применяется после первого step")


func _assert_paused_command_replay_is_deterministic() -> void:
    var first := _runner()
    var second := _runner()
    for runner: SimulationRunner in [first, second]:
        runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, 4))
        runner.enqueue(SimulationCommand.set_building_priority(1, 20, 2, 1))
    var first_hash := first.flush_commands()
    var second_hash := second.flush_commands()
    assert_eq(first_hash, second_hash, "одинаковые paused commands дают одинаковый v=6 hash")
    assert_true(StateHasher.new().canonicalize(first.state).begins_with("v=6|"), "paused hash сохраняет формат v=6")


func _assert_flush_reconciles_topology_without_running_logistics() -> void:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var runner := SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
    runner.state.logistics_links.clear()
    runner.state.next_link_id = 1
    for value: Variant in runner.state.buildings.values():
        var building := value as BuildingState
        var definition := runner.state.catalog.get_building(building.definition_id)
        if definition.role == LogisticsPortDef.ROLE_SOURCE:
            building.allows_direct_delivery_to_main = false
    var payer := runner.state.get_building(runner.state.main_warehouse_id)
    payer.add_amount(&"wood", 10)
    runner.state.generated_totals[&"wood"] = (runner.state.generated_totals.get(&"wood", 0) as int) + 10
    var coord := _prepare_empty_roadside_coord(runner.state)
    var before_inventory := 0
    for value: Variant in runner.state.buildings.values():
        before_inventory += (value as BuildingState).inventory_total()
    assert_true(runner.enqueue(DepotCommand.place(1, 40, coord)).accepted, "команда склада поставлена в очередь")

    runner.flush_commands()

    assert_eq(runner.state.tick, 0, "topology reconciliation на паузе не продвигает tick")
    assert_eq(runner.state.jobs.size(), 0, "topology-only flush не создаёт jobs")
    var after_inventory := 0
    for value: Variant in runner.state.buildings.values():
        after_inventory += (value as BuildingState).inventory_total()
    assert_eq(after_inventory, before_inventory - 10, "flush выполняет только стоимость команды, без source generation")
    var depot_id := 0
    for value: Variant in runner.state.buildings.values():
        if (value as BuildingState).definition_id == &"transfer_depot":
            depot_id = (value as BuildingState).id
    assert_true(depot_id > 0, "склад размещён")
    var has_depot_link := false
    for value: Variant in runner.state.logistics_links.values():
        var link := value as LogisticsLinkState
        has_depot_link = has_depot_link or link.destination_id == depot_id
    assert_true(has_depot_link, "размещённый на паузе склад сразу получает автоматические связи")


func _prepare_empty_roadside_coord(state: SimulationState) -> HexCoord:
    for cell: HexCellState in state.map_state.get_cells():
        if not cell.traversable or state.occupied_cells.has(cell.coord.key()):
            continue
        for neighbor: HexCoord in cell.coord.neighbors():
            if (
                state.map_state.contains(neighbor)
                and state.map_state.get_cell(neighbor).traversable
                and not state.occupied_cells.has(neighbor.key())
            ):
                state.map_state.get_cell(neighbor).road_level = RoadLevelDef.LEVEL_PATH
                return cell.coord
    return null


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
