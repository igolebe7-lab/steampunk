class_name LogisticsTestFactory
extends RefCounted


static func two_workers_same_target() -> SimulationState:
    var state := SimulationState.new(
        1,
        HexMapState.new(5, 5),
        DefinitionCatalog.new(),
        {},
        {},
        3
    )
    var first := WorkerState.new(1, HexCoord.new(1, 1))
    var second := WorkerState.new(2, HexCoord.new(3, 1))
    var target := HexCoord.new(2, 1)
    first.route = [first.coord, target]
    second.route = [second.coord, target]
    first.action = WorkerState.TO_SOURCE
    second.action = WorkerState.TO_SOURCE
    state.workers = {1: first, 2: second}
    state.worker_occupancy = {
        first.coord.key(): first.id,
        second.coord.key(): second.id,
    }
    state.worker_ticks_per_hex = 4
    return state


static func two_workers_swapping_cells() -> SimulationState:
    var state := SimulationState.new(
        1,
        HexMapState.new(5, 5),
        DefinitionCatalog.new(),
        {},
        {},
        3
    )
    var first := WorkerState.new(1, HexCoord.new(1, 1))
    var second := WorkerState.new(2, HexCoord.new(2, 1))
    first.route = [first.coord, second.coord]
    second.route = [second.coord, first.coord]
    first.action = WorkerState.TO_SOURCE
    second.action = WorkerState.TO_SOURCE
    state.workers = {1: first, 2: second}
    state.worker_occupancy = {
        first.coord.key(): first.id,
        second.coord.key(): second.id,
    }
    state.worker_ticks_per_hex = 4
    return state
