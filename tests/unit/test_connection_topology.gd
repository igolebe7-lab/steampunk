extends TestCase


func run() -> Array[String]:
    _assert_road_mask_uses_real_neighbors()
    _assert_preview_matches_future_road()
    _assert_pipe_mask_uses_segments_and_ports()
    _assert_pipe_preview_accepts_typed_commodity()
    return finish()


func _assert_road_mask_uses_real_neighbors() -> void:
    var map_state := HexMapState.new(6, 6)
    var center := HexCoord.new(2, 1)
    map_state.get_cell(center).road_level = RoadLevelDef.LEVEL_PATH
    map_state.get_cell(center.neighbor(0)).road_level = RoadLevelDef.LEVEL_PATH
    map_state.get_cell(center.neighbor(3)).road_level = RoadLevelDef.LEVEL_DIRT_ROAD

    var mask := ConnectionTopology.road_mask(map_state, center)

    assert_eq(mask, (1 << 0) | (1 << 3), "дорога соединяется только с двумя реальными соседями")
    assert_true(ConnectionTopology.has_direction(mask, 0), "восточное соединение присутствует")
    assert_true(not ConnectionTopology.has_direction(mask, 1), "ложное северо-восточное соединение отсутствует")


func _assert_preview_matches_future_road() -> void:
    var map_state := HexMapState.new(6, 6)
    var center := HexCoord.new(2, 1)
    var neighbor := center.neighbor(2)
    map_state.get_cell(center).road_level = RoadLevelDef.LEVEL_PATH
    var preview := {neighbor.key(): true}

    var preview_mask := ConnectionTopology.road_mask(map_state, center, preview)
    map_state.get_cell(neighbor).road_level = RoadLevelDef.LEVEL_PATH
    var built_mask := ConnectionTopology.road_mask(map_state, center)

    assert_eq(preview_mask, built_mask, "предпросмотр дороги совпадает с построенной топологией")
    assert_eq(preview_mask, 1 << 2, "предпросмотр включает выбранную сторону")


func _assert_pipe_mask_uses_segments_and_ports() -> void:
    var state := Stage5TestFactory.pipe_state(10)
    var center := HexCoord.new(2, 0)
    var next := HexCoord.new(3, 0)
    state.utility_network.add_segment(center, &"water")
    state.utility_network.add_segment(next, &"water")

    var mask := ConnectionTopology.pipe_mask(state, center)

    assert_eq(mask, (1 << 0) | (1 << 3), "труба соединяется с сегментом и выходным портом насосной")
    assert_true(ConnectionTopology.has_direction(mask, 3), "порт насосной входит в маску трубы")


func _assert_pipe_preview_accepts_typed_commodity() -> void:
    var state := Stage5TestFactory.pipe_state(10)
    var center := HexCoord.new(2, 0)
    var next := HexCoord.new(3, 0)
    var preview := {
        center.key(): &"water",
        next.key(): &"water",
    }

    var mask := ConnectionTopology.pipe_mask(state, center, preview)

    assert_eq(mask, (1 << 0) | (1 << 3), "typed preview соединяется с сегментом и портом")
