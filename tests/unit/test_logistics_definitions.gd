extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    assert_true(scenario != null, "логистический сценарий должен загружаться")
    if scenario == null:
        return finish()
    assert_eq(scenario.initial_buildings.size(), 3, "нужны два источника и склад")
    assert_eq(scenario.initial_workers.size(), 6, "нужны шесть носильщиков")
    assert_eq(scenario.delivery_flows.size(), 2, "нужны два потока к складу")
    assert_eq(scenario.worker_ticks_per_hex, 4, "гекс проходится за четыре тика")
    var source := scenario.catalog.get_building(&"wood_source")
    assert_true(source != null and source.is_source(), "wood_source должен быть источником")
    if source != null:
        assert_eq(source.source_resource_id, &"wood", "источник создаёт древесину")
        assert_eq(source.source_interval_ticks, 10, "интервал источника равен десяти тикам")
    return finish()
