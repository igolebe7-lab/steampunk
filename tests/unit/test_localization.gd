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
    return finish()
