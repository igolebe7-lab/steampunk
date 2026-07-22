extends "res://tests/test_case.gd"


func run() -> Array[String]:
    TranslationServer.set_locale("ru")
    assert_eq(
        TranslationServer.translate(&"ui.app.title"),
        &"Паровая логистика",
        "заголовок должен переводиться на русский"
    )
    assert_true(
        ThemeDB.fallback_font.has_char("Ж".unicode_at(0)),
        "fallback-шрифт Godot должен содержать кириллицу"
    )
    var required_keys: Array[StringName] = [
        &"ui.hud.wood", &"ui.hud.throughput", &"ui.hud.tick", &"ui.hud.pause",
        &"ui.hud.speed_1", &"ui.hud.speed_2", &"ui.hud.speed_4",
        &"ui.camera.zoom_out", &"ui.camera.zoom_in", &"ui.camera.fit", &"ui.camera.fit_hint",
        &"ui.layer.links", &"ui.layer.routes", &"ui.layer.load",
        &"ui.layer.utilities", &"phase.observation", &"phase.site_preparation",
        &"phase.boiler_supply", &"phase.warming", &"phase.first_strike", &"phase.completed",
        &"ui.tool.inspect", &"ui.tool.road", &"ui.tool.depot", &"ui.tool.link",
        &"ui.tool.pipe_build", &"ui.tool.pipe_remove", &"ui.result.title", &"ui.result.continue",
        &"ui.management.quota", &"ui.management.priority", &"ui.management.dispatch",
        &"ui.management.apply_link", &"ui.management.remove_link", &"ui.management.reset_link",
        &"ui.management.direct_main", &"ui.management.apply_direct",
        &"ui.management.demolish_depot",
        &"ui.inspector.worker", &"ui.inspector.building", &"ui.inspector.link",
        &"reason.no_destination", &"reason.destination_full", &"reason.source_full",
        &"reason.worker_shortage", &"reason.route_conflict", &"reason.relay_backlog",
        &"reason.no_path", &"command.accepted", &"command.insufficient_wood",
        &"reason.no_coal", &"reason.no_water", &"reason.boiler_not_hot",
        &"command.unknown", &"playtest.error.invalid_session_id",
        &"playtest.error.storage_write", &"playtest.error.report_too_large",
        &"playtest.error.recovered_interrupted", &"playtest.error.result_exists",
    ]
    var command_codes: Array[StringName] = [
        &"invalid_command", &"past_tick", &"duplicate_sequence", &"unsupported_command",
        &"unknown_building", &"invalid_priority", &"empty_road_batch", &"cell_missing",
        &"duplicate_cell", &"cell_not_traversable", &"cell_occupied", &"invalid_road_level",
        &"road_level_max", &"missing_road_level", &"insufficient_wood",
        &"transfer_depot_exists", &"depot_not_adjacent_to_road", &"unknown_building_definition",
        &"unknown_transfer_depot", &"depot_not_empty", &"depot_has_reservations",
        &"depot_has_active_jobs", &"depot_has_active_cargo", &"main_warehouse_full",
        &"duplicate_link", &"link_cycle", &"incompatible_link", &"source_slots_exceeded",
        &"no_path", &"unknown_link", &"invalid_link_settings", &"link_quota_in_use",
        &"invalid_dispatch_source", &"unknown_main_warehouse",
        &"empty_pipe_path", &"pipe_cell_occupied", &"pipe_segment_exists",
        &"invalid_pipe_origin", &"invalid_pipe_destination", &"insufficient_iron",
        &"pipe_segment_missing", &"incompatible_utility_type", &"invalid_pipe_path",
    ]
    for code: StringName in command_codes:
        required_keys.append(StringName("command.%s" % code))
    for locale in [&"ru", &"en"]:
        TranslationServer.set_locale(locale)
        for key: StringName in required_keys:
            assert_true(TranslationServer.translate(key) != key, "ключ %s переведён для %s" % [key, locale])
        var hud := HUDController.new()
        assert_true(
            hud.localized_command_message(&"not_a_real_code") != "command.not_a_real_code",
            "HUD не показывает сырой ключ неизвестной ошибки для %s" % locale
        )
    TranslationServer.set_locale("ru")
    return finish()
