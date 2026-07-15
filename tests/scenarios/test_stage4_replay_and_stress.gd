extends TestCase

const STRESS_TICKS := 10000


func run() -> Array[String]:
    var first := _runner()
    var second := _runner()
    for tick in range(1, STRESS_TICKS + 1):
        if tick == 21:
            _enqueue_link_trace(first, tick)
            _enqueue_link_trace(second, tick)
        var first_hash := first.step()
        var second_hash := second.step()
        assert_true(not first_hash.is_empty() and not second_hash.is_empty(), "stress runner сохраняет инварианты на tick %d" % tick)
        assert_eq(first_hash, second_hash, "stress replay совпадает на tick %d" % tick)
        if not _failures.is_empty():
            break
    assert_eq(first.state.tick, STRESS_TICKS, "stress выполняет 10 000 тиков")
    assert_eq(_wood_in_world(first.state), first.state.generated_totals.get(&"wood", 0), "stress не теряет и не дублирует груз")
    assert_true(InvariantChecker.new().check(first.state).is_empty(), "stress сохраняет все инварианты")
    return finish()


func _enqueue_link_trace(runner: SimulationRunner, target_tick: int) -> void:
    var ids: Array = runner.state.logistics_links.keys()
    ids.sort()
    var link := runner.state.logistics_links[ids[0]] as LogisticsLinkState
    runner.enqueue(LinkCommand.create(target_tick, 100, link.source_id, link.destination_id, link.resource_id))
    runner.enqueue(LinkSettingsCommand.new(target_tick + 200, 200, link.id, 2, 4, true))
    runner.enqueue(LinkSettingsCommand.new(target_tick + 400, 300, link.id, 2, 4, false))
    runner.enqueue(LinkSettingsCommand.new(target_tick + 500, 400, link.id, 2, 3, true))
    runner.enqueue(LinkCommand.remove(target_tick + 700, 500, link.id))
    runner.enqueue(LinkCommand.reset_automatic(target_tick + 900, 600, link.source_id, link.resource_id))


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)


func _wood_in_world(state: SimulationState) -> int:
    var total := 0
    for value: Variant in state.buildings.values():
        total += (value as BuildingState).get_amount(&"wood")
    for value: Variant in state.workers.values():
        total += 1 if (value as WorkerState).cargo_resource_id == &"wood" else 0
    return total
