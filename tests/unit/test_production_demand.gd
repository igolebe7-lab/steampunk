extends TestCase


func run() -> Array[String]:
    _assert_boiler_requests_three_cycles_without_overbooking()
    _assert_locked_production_has_no_demand()
    _assert_sources_cannot_bypass_storage()
    return finish()


func _assert_boiler_requests_three_cycles_without_overbooking() -> void:
    var state := Stage5TestFactory.production_state()
    var main := Stage5TestFactory.building(state, &"main_warehouse")
    var boiler := Stage5TestFactory.building(state, &"boiler")
    var production := Stage5TestFactory.production(state, &"boiler")
    production.status = ProductionState.WAITING_INPUTS
    main.inventories[&"water"] = 10
    boiler.inventories[&"water"] = 2
    boiler.incoming_reserved[&"water"] = 1
    Stage5TestFactory.isolate_link(state, main.id, boiler.id, &"water", 4)

    JobSystem.new().run(state, 1)

    assert_eq(_requested(state, boiler.id, &"water"), 3, "цель 6 учитывает запас и резерв")
    for value: Variant in state.jobs.values():
        assert_eq((value as DeliveryJob).source_id, main.id, "производство получает ресурс со склада")


func _assert_locked_production_has_no_demand() -> void:
    var state := Stage5TestFactory.production_state()
    var main := Stage5TestFactory.building(state, &"main_warehouse")
    var boiler := Stage5TestFactory.building(state, &"boiler")
    main.inventories[&"water"] = 10
    Stage5TestFactory.isolate_link(state, main.id, boiler.id, &"water", 4)

    JobSystem.new().run(state, 1)

    assert_eq(state.jobs.size(), 0, "заблокированный котёл не перетягивает работников и ресурсы")


func _assert_sources_cannot_bypass_storage() -> void:
    var state := Stage5TestFactory.production_state()
    var source := Stage5TestFactory.building(state, &"water_source")
    var main := Stage5TestFactory.building(state, &"main_warehouse")
    var boiler := Stage5TestFactory.building(state, &"boiler")
    var links := LogisticsLinkSystem.new()
    assert_true(not links.is_compatible(state, source.id, boiler.id, &"water"), "источник не доставляет прямо в производство")
    assert_true(links.is_compatible(state, main.id, boiler.id, &"water"), "склад снабжает производство")


func _requested(state: SimulationState, destination_id: int, resource_id: StringName) -> int:
    var result := 0
    for value: Variant in state.jobs.values():
        var job := value as DeliveryJob
        if job.destination_id == destination_id and job.resource_id == resource_id:
            result += 1
    return result
