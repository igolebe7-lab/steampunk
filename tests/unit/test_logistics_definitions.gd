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
    var main_warehouse := scenario.catalog.get_building(&"main_warehouse")
    assert_true(main_warehouse != null, "main_warehouse должен быть в каталоге")
    if main_warehouse != null:
        assert_eq(main_warehouse.role, LogisticsPortDef.ROLE_MAIN_WAREHOUSE, "главный склад имеет отдельную роль")
        assert_eq(main_warehouse.inventory_capacity, 100, "главный склад вмещает 100")
    var transfer_depot := scenario.catalog.get_building(&"transfer_depot")
    assert_true(transfer_depot != null, "transfer_depot должен быть в каталоге")
    if transfer_depot != null:
        assert_eq(transfer_depot.role, LogisticsPortDef.ROLE_TRANSFER_DEPOT, "перевалочный склад имеет отдельную роль")
        assert_eq(transfer_depot.inventory_capacity, 40, "перевалочный склад вмещает 40")
        assert_eq(transfer_depot.outgoing_worker_slots(1), 2, "перевалочный склад имеет два места")
    var source := scenario.catalog.get_building(&"wood_source")
    assert_true(source != null and source.is_source(), "wood_source должен быть источником")
    if source != null:
        assert_eq(source.source_resource_id, &"wood", "источник создаёт древесину")
        assert_eq(source.source_interval_ticks, 10, "интервал источника равен десяти тикам")
    return finish()
