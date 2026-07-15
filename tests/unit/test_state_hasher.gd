extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var first := ScenarioLoader.new().load_scenario(scenario).state
    var second := ScenarioLoader.new().load_scenario(scenario).state
    assert_true(first != null and second != null, "хэшеру требуются два загруженных состояния")
    if first == null or second == null:
        return finish()

    var hasher := StateHasher.new()
    assert_true(
        hasher.canonicalize(first).begins_with("v=5|"),
        "каноническое представление должно использовать формат v=5"
    )
    assert_eq(
        hasher.canonicalize(first),
        hasher.canonicalize(second),
        "одинаковые состояния должны иметь одинаковое каноническое представление"
    )
    var initial_hash := hasher.hash_state(first)
    assert_eq(initial_hash.length(), 64, "SHA-256 должен содержать 64 шестнадцатеричных символа")
    assert_eq(initial_hash, hasher.hash_state(second), "одинаковые состояния должны иметь одинаковый хэш")

    var reordered: Dictionary = {}
    for id in [3, 2, 1]:
        reordered[id] = second.buildings[id]
    second.buildings = reordered
    assert_eq(initial_hash, hasher.hash_state(second), "порядок Dictionary не должен влиять на хэш")

    second.get_building(1).priority = 4
    assert_true(initial_hash != hasher.hash_state(second), "изменение состояния должно менять хэш")

    var changed_map := ScenarioLoader.new().load_scenario(scenario).state
    var first_cell := changed_map.map_state.get_cells()[0]
    changed_map.map_state.set_movement_cost(first_cell.coord, 2)
    assert_true(
        initial_hash != hasher.hash_state(changed_map),
        "изменение клетки карты должно менять хэш состояния"
    )
    _assert_stage4_state_changes_hash(hasher, scenario, initial_hash)
    _assert_logistics_dictionary_order_is_ignored(hasher)
    _assert_telemetry_changes_hash_deterministically(hasher, scenario)
    return finish()


func _assert_stage4_state_changes_hash(
    hasher: StateHasher,
    scenario: ScenarioDef,
    initial_hash: String
) -> void:
    var changed_road := ScenarioLoader.new().load_scenario(scenario).state
    changed_road.map_state.get_cells()[0].road_level = RoadLevelDef.LEVEL_PATH
    assert_true(initial_hash != hasher.hash_state(changed_road), "уровень дороги должен менять v=5 hash")

    var changed_revision := ScenarioLoader.new().load_scenario(scenario).state
    changed_revision.revision = 1
    assert_true(initial_hash != hasher.hash_state(changed_revision), "ревизия должна менять v=5 hash")

    var changed_link := ScenarioLoader.new().load_scenario(scenario).state
    changed_link.logistics_links[2] = LogisticsLinkState.new(2, 1, 3, &"wood", false, 1, 2)
    assert_true(initial_hash != hasher.hash_state(changed_link), "логистическая связь должна менять v=5 hash")

    var changed_slots := ScenarioLoader.new().load_scenario(scenario).state
    var source_definition := changed_slots.catalog.get_building(&"wood_source")
    var original_slots := source_definition.outgoing_worker_slots_by_level.duplicate()
    source_definition.outgoing_worker_slots_by_level = [2, 4, 6]
    assert_true(initial_hash != hasher.hash_state(changed_slots), "полная таблица рабочих мест должна менять v=5 hash")
    source_definition.outgoing_worker_slots_by_level = original_slots

    var changed_ports := ScenarioLoader.new().load_scenario(scenario).state
    source_definition = changed_ports.catalog.get_building(&"wood_source")
    var extra_port := LogisticsPortDef.new()
    extra_port.direction = LogisticsPortDef.DIRECTION_OUTPUT
    extra_port.resource_id = &"wood"
    extra_port.accepted_building_roles = [LogisticsPortDef.ROLE_MAIN_WAREHOUSE]
    source_definition.logistics_ports.append(extra_port)
    assert_true(initial_hash != hasher.hash_state(changed_ports), "совместимость логистических портов должна менять v=5 hash")
    source_definition.logistics_ports.pop_back()


func _assert_logistics_dictionary_order_is_ignored(hasher: StateHasher) -> void:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    SimulationRunner.new(state).run_ticks(100)
    state.logistics_links[2] = LogisticsLinkState.new(2, 1, 3, &"wood", false, 1, 2)
    state.logistics_links[1] = LogisticsLinkState.new(1, 2, 3, &"wood", true, 1, 1)
    var expected := hasher.hash_state(state)

    state.buildings = _reversed_dictionary(state.buildings)
    state.workers = _reversed_dictionary(state.workers)
    state.jobs = _reversed_dictionary(state.jobs)
    state.worker_occupancy = _reversed_dictionary(state.worker_occupancy)
    state.cell_reservations = _reversed_dictionary(state.cell_reservations)
    state.generated_totals = _reversed_dictionary(state.generated_totals)
    state.delivered_totals = _reversed_dictionary(state.delivered_totals)
    state.logistics_links = _reversed_dictionary(state.logistics_links)
    state.delivery_flows.reverse()
    for value: Variant in state.buildings.values():
        var building := value as BuildingState
        building.inventories = _reversed_dictionary(building.inventories)
        building.outgoing_reserved = _reversed_dictionary(building.outgoing_reserved)
        building.incoming_reserved = _reversed_dictionary(building.incoming_reserved)

    assert_eq(
        hasher.hash_state(state),
        expected,
        "порядок всех logistics Dictionary и flows не влияет на v5 hash"
    )


func _reversed_dictionary(source: Dictionary) -> Dictionary:
    var keys := source.keys()
    keys.reverse()
    var result: Dictionary = {}
    for key: Variant in keys:
        result[key] = source[key]
    return result


func _assert_telemetry_changes_hash_deterministically(hasher: StateHasher, scenario: ScenarioDef) -> void:
    var first := ScenarioLoader.new().load_scenario(scenario).state
    var second := ScenarioLoader.new().load_scenario(scenario).state
    first.telemetry_window.append_sample({
        &"tick": 1,
        &"losses": {&"no_path": 2, &"route_conflict": 1},
        &"link_load": {2: 1, 1: 3},
    })
    second.telemetry_window.append_sample({
        &"link_load": {1: 3, 2: 1},
        &"losses": {&"route_conflict": 1, &"no_path": 2},
        &"tick": 1,
    })
    first.diagnostic_report = DiagnosticReport.new(&"no_path", 2, 2, &"3:4")
    second.diagnostic_report = DiagnosticReport.new(&"no_path", 2, 2, &"3:4")
    assert_eq(hasher.hash_state(first), hasher.hash_state(second), "порядок telemetry Dictionary не влияет на hash")
    second.telemetry_window.append_sample({&"tick": 2, &"losses": {&"no_path": 1}})
    assert_true(hasher.hash_state(first) != hasher.hash_state(second), "сохранённое telemetry window меняет hash")
