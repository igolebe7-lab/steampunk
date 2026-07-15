extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var finder := Pathfinder.new()
    var link := state.logistics_links[1] as LogisticsLinkState
    var goals := finder.interaction_cells(state, link.source_id)
    var worker_ids: Array = state.workers.keys()
    worker_ids.sort()
    var start := state.get_worker(worker_ids[0]).coord
    var first := finder.find_path(state, start, goals)
    var second := finder.find_path(state, start, goals)
    assert_true(first.is_success(), "путь должен находиться")
    assert_eq(first.keys(), second.keys(), "путь должен быть детерминирован")
    for coord in first.path:
        assert_true(not state.occupied_cells.has(coord.key()), "путь не входит в footprint")

    var blocked: Dictionary = {}
    for cell in state.map_state.get_cells():
        if cell.coord.q == 1:
            blocked[cell.coord.key()] = true
    var missing := finder.find_path(state, HexCoord.new(0, 0), [HexCoord.new(2, 0)], blocked)
    assert_true(not missing.is_success(), "непроходимый барьер должен возвращать no_path")
    return finish()
