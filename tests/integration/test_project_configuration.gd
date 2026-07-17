extends TestCase

const REQUIRED_KEYS := [
    "ui.app.title",
    "ui.status.select_hex",
    "ui.status.selected_hex",
    "resource.wood.name",
    "resource.iron.name",
    "resource.coal.name",
    "resource.water.name",
    "building.transfer_depot.name",
    "building.boiler.name",
    "building.steam_hammer.name",
    "building.wood_source.name",
    "ui.mode.inspect",
    "ui.mode.pipe_build",
    "ui.hint.inspect",
    "ui.hint.pipe_build",
    "ui.action.confirm_cost",
    "ui.action.cancel",
    "ui.tooltip.pipe_build",
]

func run() -> Array[String]:
    assert_eq(
        ProjectSettings.get_setting("internationalization/locale/fallback"),
        "ru",
        "базовая локаль должна быть русской"
    )
    assert_eq(
        ProjectSettings.get_setting("application/run/main_scene"),
        "res://scenes/main.tscn",
        "главная сцена должна быть настроена"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/viewport_width"),
        1920,
        "проектная ширина должна быть 1920"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/viewport_height"),
        1080,
        "проектная высота должна быть 1080"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/window_width_override"),
        1600,
        "оконный override должен быть 1600"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/window_height_override"),
        900,
        "оконный override должен быть 900"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/mode"),
        2,
        "игра должна запускаться развёрнутой"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/stretch/mode"),
        "canvas_items",
        "HUD должен масштабироваться как canvas items"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/stretch/aspect"),
        "expand",
        "широкий экран должен расширять полезную область"
    )

    var translation_paths: PackedStringArray = ProjectSettings.get_setting(
        "internationalization/locale/translations",
        PackedStringArray()
    )
    assert_true(
        translation_paths.has("res://localization/game.ru.translation"),
        "русский ресурс перевода должен загружаться проектом"
    )
    assert_true(
        translation_paths.has("res://localization/game.en.translation"),
        "английский ресурс перевода должен загружаться проектом"
    )
    _assert_catalog_complete("res://localization/game.csv")
    _assert_required_data_loads()

    TranslationServer.set_locale("en")
    assert_eq(
        TranslationServer.translate(&"ui.app.title"),
        &"Steam Logistics",
        "тестовая английская локаль должна подключаться без изменения кода"
    )
    TranslationServer.set_locale("ru")
    return finish()


func _assert_required_data_loads() -> void:
    var catalog := load("res://data/catalog.tres")
    var foundation := load("res://data/scenarios/foundation.tres")
    var physical_logistics := load("res://data/scenarios/physical_logistics.tres")
    assert_true(catalog is DefinitionCatalog, "каталог должен загружаться как DefinitionCatalog")
    assert_true(foundation is ScenarioDef, "базовый сценарий должен загружаться как ScenarioDef")
    assert_true(
        physical_logistics is ScenarioDef,
        "сценарий физической логистики должен загружаться как ScenarioDef"
    )


func _assert_catalog_complete(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    assert_true(file != null, "CSV-каталог должен открываться")
    if file == null:
        return

    var header := file.get_csv_line()
    assert_true(header.size() >= 3, "CSV должен содержать keys, ru и en")
    assert_eq(header[0], "keys", "первый столбец должен называться keys")
    assert_eq(header[1], "ru", "второй столбец должен быть русским")

    var seen_keys: Dictionary = {}
    while not file.eof_reached():
        var row := file.get_csv_line()
        if row.is_empty() or (row.size() == 1 and row[0].is_empty()):
            continue
        assert_true(row.size() >= 3, "каждая строка должна иметь три столбца")
        if row.size() < 3:
            continue
        assert_true(not row[0].is_empty(), "ключ локализации не может быть пустым")
        assert_true(not seen_keys.has(row[0]), "ключ локализации не должен повторяться: %s" % row[0])
        assert_true(not row[1].is_empty(), "русское значение не может быть пустым: %s" % row[0])
        seen_keys[row[0]] = true

    for required_key in REQUIRED_KEYS:
        assert_true(seen_keys.has(required_key), "обязательный ключ отсутствует в CSV: %s" % required_key)
