class_name Pathfinder
extends RefCounted


func find_path(
    state: SimulationState,
    start: HexCoord,
    goals: Array[HexCoord],
    dynamic_blocked: Dictionary = {}
) -> PathResult:
    if state == null or start == null or goals.is_empty() or not state.map_state.contains(start):
        return PathResult.new()

    var goal_keys: Dictionary = {}
    for goal in goals:
        if state.map_state.contains(goal):
            goal_keys[goal.key()] = true
    if goal_keys.is_empty():
        return PathResult.new()

    var open: Array[Dictionary] = [{
        "coord": start,
        "g": 0,
        "f": _heuristic(start, goals),
    }]
    var g_score: Dictionary = {start.key(): 0}
    var came_from: Dictionary = {}
    var coords: Dictionary = {start.key(): start}
    var closed: Dictionary = {}

    while not open.is_empty():
        open.sort_custom(_sort_open)
        var current_entry: Dictionary = open.pop_front()
        var current := current_entry["coord"] as HexCoord
        var current_key := current.key()
        if closed.has(current_key):
            continue
        if goal_keys.has(current_key):
            return _reconstruct(current, came_from, coords, g_score[current_key] as int)
        closed[current_key] = true

        for neighbor in current.neighbors():
            var neighbor_key := neighbor.key()
            if closed.has(neighbor_key) or not state.map_state.contains(neighbor):
                continue
            var cell := state.map_state.get_cell(neighbor)
            if not cell.traversable or state.occupied_cells.has(neighbor_key) or dynamic_blocked.has(neighbor_key):
                continue
            var tentative := (g_score[current_key] as int) + cell.movement_cost
            if g_score.has(neighbor_key) and tentative >= (g_score[neighbor_key] as int):
                continue
            came_from[neighbor_key] = current_key
            coords[neighbor_key] = neighbor
            g_score[neighbor_key] = tentative
            open.append({
                "coord": neighbor,
                "g": tentative,
                "f": tentative + _heuristic(neighbor, goals),
            })
    return PathResult.new()


func interaction_cells(state: SimulationState, building_id: int) -> Array[HexCoord]:
    var candidates: Dictionary = {}
    for cell in state.map_state.get_cells():
        if state.occupied_cells.get(cell.coord.key(), 0) != building_id:
            continue
        for neighbor in cell.coord.neighbors():
            if not state.map_state.contains(neighbor):
                continue
            var neighbor_cell := state.map_state.get_cell(neighbor)
            if neighbor_cell.traversable and not state.occupied_cells.has(neighbor.key()):
                candidates[neighbor.key()] = neighbor
    var result: Array[HexCoord] = []
    for candidate in candidates.values():
        result.append(candidate as HexCoord)
    result.sort_custom(_sort_coords)
    return result


func _heuristic(coord: HexCoord, goals: Array[HexCoord]) -> int:
    var result := 1 << 30
    for goal in goals:
        result = mini(result, coord.distance_to(goal))
    return result


func _reconstruct(goal: HexCoord, came_from: Dictionary, coords: Dictionary, cost: int) -> PathResult:
    var reversed: Array[HexCoord] = [goal]
    var key := goal.key()
    while came_from.has(key):
        key = came_from[key] as StringName
        reversed.append(coords[key] as HexCoord)
    reversed.reverse()
    return PathResult.new(reversed, cost)


func _sort_open(left: Dictionary, right: Dictionary) -> bool:
    if (left["f"] as int) != (right["f"] as int):
        return (left["f"] as int) < (right["f"] as int)
    if (left["g"] as int) != (right["g"] as int):
        return (left["g"] as int) < (right["g"] as int)
    return _sort_coords(left["coord"] as HexCoord, right["coord"] as HexCoord)


func _sort_coords(left: HexCoord, right: HexCoord) -> bool:
    if left.q == right.q:
        return left.r < right.r
    return left.q < right.q
