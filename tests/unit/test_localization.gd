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
        &"ui.layer.links", &"ui.layer.routes", &"ui.layer.load",
        &"ui.tool.inspect", &"ui.tool.road", &"ui.tool.depot", &"ui.tool.link",
        &"ui.inspector.worker", &"ui.inspector.building", &"ui.inspector.link",
        &"reason.no_destination", &"reason.destination_full", &"reason.source_full",
        &"reason.worker_shortage", &"reason.route_conflict", &"reason.relay_backlog",
        &"reason.no_path", &"command.accepted", &"command.insufficient_wood",
    ]
    for locale in [&"ru", &"en"]:
        TranslationServer.set_locale(locale)
        for key: StringName in required_keys:
            assert_true(TranslationServer.translate(key) != key, "ключ %s переведён для %s" % [key, locale])
    TranslationServer.set_locale("ru")
    return finish()
