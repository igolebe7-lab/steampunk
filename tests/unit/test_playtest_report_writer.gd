extends TestCase


func run() -> Array[String]:
    var session := PlaytestSession.new("PT-REPORT", "abc1234", 123)
    session.append(1000, 10, &"command", &"link_settings", {&"result": &"accepted"})
    session.append(1500, 11, &"simulation", &"mystery_event", {})
    session.finish(&"completed", 90_000, 900)
    var analysis := {
        "milestones": {"first_logistics_action_ms": 1000},
        "idle_periods": [],
        "water_path": "pipe",
        "command_counts": {"accepted": 1, "rejected": 0},
        "layer_usage": {"routes": 1},
        "bottleneck_candidates": [],
    }
    var writer := PlaytestReportWriter.new()
    var json_text := writer.build_json(session, analysis)
    var markdown := writer.build_markdown(session, analysis, &"ru")

    assert_eq(
        PlaytestReportCatalog.text(&"result", &"en"),
        "Result",
        "каталог допускает английский отчёт"
    )
    assert_true(json_text.length() > 0, "JSON построен")
    assert_true(JSON.parse_string(json_text) is Dictionary, "JSON разбирается")
    assert_true(markdown.contains("# Отчёт плейтеста PT-REPORT"), "русский заголовок есть")
    assert_true(markdown.contains("## Ответы игрока"), "место для ответов есть")
    assert_true(markdown.contains("## Заметки наблюдателя"), "место для заметок есть")
    assert_true(
        markdown.contains("Неизвестное событие: mystery_event"),
        "неизвестный код явно отмечен"
    )

    var root := "user://playtest-tests/PT-REPORT-%d" % Time.get_ticks_usec()
    var storage := PlaytestStorage.new(root)
    var first := storage.write_checkpoint(session, json_text)
    var second := storage.write_checkpoint(session, json_text)
    assert_true(first["ok"] and second["ok"], "оба checkpoint записаны")
    assert_true(first["path"] != second["path"], "слоты a/b чередуются")
    var broken := FileAccess.open(second["path"], FileAccess.WRITE)
    broken.store_string("{")
    broken.close()
    var recovered := storage.load_latest_checkpoint("PT-REPORT")
    assert_true(recovered["ok"], "повреждённый слот не скрывает корректный checkpoint")
    assert_eq(recovered["path"], first["path"], "выбран корректный слот")
    assert_eq(
        recovered["data"]["session"]["id"],
        "PT-REPORT",
        "восстановлена нужная сессия"
    )

    var final_result := storage.write_final(session, json_text, markdown)
    assert_true(final_result["ok"], "два финальных файла записаны")
    assert_true(FileAccess.file_exists(final_result["json_path"]), "итоговый JSON существует")
    assert_true(
        FileAccess.file_exists(final_result["markdown_path"]),
        "итоговый Markdown существует"
    )
    assert_true(
        not (storage.write_final(session, json_text, markdown)["ok"] as bool),
        "готовый результат не перезаписывается"
    )
    var too_large := storage.write_checkpoint(session, "x".repeat(1_048_577))
    assert_eq(too_large["error"], "report_too_large", "лимит 1 МБ проверяется до записи")
    return finish()
