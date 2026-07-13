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
        1280,
        "ширина viewport должна быть 1280"
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
    var scenario := load("res://data/scenarios/foundation.tres")
    assert_true(catalog is DefinitionCatalog, "каталог должен загружаться как DefinitionCatalog")
    assert_true(scenario is ScenarioDef, "сценарий должен загружаться как ScenarioDef")


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
