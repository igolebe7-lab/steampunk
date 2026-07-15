extends TestCase

const WOOD := &"wood"


func run() -> Array[String]:
    var state := LogisticsGraphTestFactory.basic()
    state.logistics_topology_dirty = false
    state.logistics_links = {
        1: LogisticsLinkState.new(1, 1, 3, WOOD, false, 2, 2),
        2: LogisticsLinkState.new(2, 3, 2, WOOD, false, 2, 1),
    }
    state.next_link_id = 3
    var coords := [
        HexCoord.new(1, 2),
        HexCoord.new(2, 2),
        HexCoord.new(4, 2),
        HexCoord.new(5, 2),
    ]
    for index in coords.size():
        var worker_id := 4 + index
        var worker := WorkerState.new(worker_id, coords[index])
        state.workers[worker_id] = worker
        state.worker_occupancy[worker.coord.key()] = worker_id
    state.next_entity_id = 8

    var runner := SimulationRunner.new(state)
    runner.run_ticks(1200)
    assert_true(state.get_building(2).get_amount(WOOD) > 0, "древесина проходит source → relay → main")
    assert_eq(_wood_in_world(state), state.generated_totals.get(WOOD, 0), "relay не теряет и не дублирует груз")
    assert_eq(InvariantChecker.new().check(state), [], "длительный relay-flow сохраняет инварианты")
    return finish()


func _wood_in_world(state: SimulationState) -> int:
    var total := 0
    for value: Variant in state.buildings.values():
        total += (value as BuildingState).get_amount(WOOD)
    for value: Variant in state.workers.values():
        total += 1 if (value as WorkerState).cargo_resource_id == WOOD else 0
    return total
