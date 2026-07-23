extends TestCase


func run() -> Array[String]:
    var stage_text := FileAccess.get_file_as_string(
        "res://docs/stages/06-playtest-and-art-pass.md"
    )
    var guide_text := FileAccess.get_file_as_string(
        "res://docs/playtests/observer-guide.md"
    )
    var summary_text := FileAccess.get_file_as_string(
        "res://docs/playtests/summary-template.md"
    )
    var invalid_text := FileAccess.get_file_as_string(
        "res://docs/playtests/PT-V01-invalid-summary.ru.md"
    )
    var resource_invalid_text := FileAccess.get_file_as_string(
        "res://docs/playtests/PT-R01-invalid-summary.ru.md"
    )
    assert_true(stage_text.contains("PT-S01"), "этап указывает новую серию")
    assert_true(stage_text.contains("технически недействитель"), "PT-V01 исключён из результатов")
    assert_true(guide_text.contains("PT-S01`…`PT-S05"), "инструкция использует заменяющие ID")
    assert_true(not summary_text.contains("| PT-V01 |"), "невалидная сессия не занимает строку серии")
    assert_true(not summary_text.contains("| PT-R01 |"), "дефектная сессия не занимает строку серии")
    assert_true(summary_text.contains("| PT-S05 |"), "сводка содержит пять заменяющих сессий")
    assert_true(invalid_text.contains("ed184df"), "диагностика фиксирует проверенную сборку")
    assert_true(invalid_text.contains("05:29"), "диагностика фиксирует длительность")
    assert_true(resource_invalid_text.contains("4b2ef2c"), "диагностика фиксирует сборку дефекта ресурсов")
    assert_true(resource_invalid_text.contains("00:50"), "диагностика фиксирует длительность PT-R01")
    return finish()
