extends TestCase


func run() -> Array[String]:
    assert_true(ResourceLoader.exists("res://src/simulation/systems/utility_network_system.gd"), "система инженерной сети существует")
    if not ResourceLoader.exists("res://src/simulation/systems/utility_network_system.gd"):
        return finish()
    _assert_connected_pump_fills_without_overbooking()
    _assert_broken_path_stops_flow()
    _assert_insertion_order_does_not_change_flow()
    return finish()


func _assert_connected_pump_fills_without_overbooking() -> void:
    var state := Stage5TestFactory.connected_pipe_state()
    var boiler := Stage5TestFactory.building(state, &"boiler")
    boiler.incoming_reserved[&"water"] = boiler.inventory_capacity
    var system := UtilityNetworkSystem.new()
    system.run(state, 20)
    assert_eq(boiler.get_amount(&"water"), 0, "резерв блокирует переполнение")

    boiler.incoming_reserved.clear()
    system.run(state, 40)
    assert_eq(boiler.get_amount(&"water"), 1, "насос подал единицу воды")
    assert_eq(state.utility_network.pipe_water_delivered, 1, "канал трубы измерен")
    assert_eq(state.telemetry_window.cumulative_pipe_water_delivered, 1, "труба входит в телеметрию")
    assert_eq(state.jobs.size(), 0, "труба не создаёт работу носильщика")


func _assert_broken_path_stops_flow() -> void:
    var state := Stage5TestFactory.connected_pipe_state()
    assert_true(
        CommandSystem.new().apply(state, PipeCommand.remove(2, 2, [HexCoord.new(3, 0)])).accepted,
        "средний сегмент разбирается"
    )
    UtilityNetworkSystem.new().run(state, 20)
    assert_eq(Stage5TestFactory.building(state, &"boiler").get_amount(&"water"), 0, "разрыв останавливает поток")


func _assert_insertion_order_does_not_change_flow() -> void:
    var first := Stage5TestFactory.pipe_state()
    var second := Stage5TestFactory.pipe_state()
    var path := Stage5TestFactory.pipe_path()
    for coord: HexCoord in path:
        first.utility_network.add_segment(coord, &"water")
    for index in range(path.size() - 1, -1, -1):
        second.utility_network.add_segment(path[index], &"water")

    UtilityNetworkSystem.new().run(first, 20)
    UtilityNetworkSystem.new().run(second, 20)

    assert_eq(
        Stage5TestFactory.building(first, &"boiler").get_amount(&"water"),
        Stage5TestFactory.building(second, &"boiler").get_amount(&"water"),
        "порядок вставки сегментов не меняет поток"
    )
    assert_eq(_components(first), _components(second), "компоненты каноничны")


func _components(state: SimulationState) -> PackedStringArray:
    var result: PackedStringArray = []
    var keys := state.utility_network.segments.keys()
    keys.sort()
    for key: Variant in keys:
        var segment := state.utility_network.segments[key] as UtilitySegmentState
        result.append("%s=%s" % [key, segment.component_id])
    return result
