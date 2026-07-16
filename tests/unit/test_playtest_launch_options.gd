extends TestCase


func run() -> Array[String]:
    var disabled := PlaytestLaunchOptions.parse(PackedStringArray(), "0.6.0")
    assert_true(not disabled.enabled, "без аргумента режим выключен")

    var enabled := PlaytestLaunchOptions.parse(PackedStringArray([
        "--playtest-session=PT-001",
        "--playtest-build=abc1234",
    ]), "0.6.0")
    assert_true(enabled.enabled, "валидная сессия включена")
    assert_eq(enabled.session_id, "PT-001", "идентификатор разобран")
    assert_eq(enabled.build_revision, "abc1234", "SHA разобран")

    var fallback := PlaytestLaunchOptions.parse(PackedStringArray([
        "--playtest-session=PT-002",
        "--playtest-build=",
    ]), "0.6.0")
    assert_eq(fallback.build_revision, "0.6.0", "пустая сборка использует версию проекта")

    var invalid := PlaytestLaunchOptions.parse(PackedStringArray([
        "--playtest-session=../bad",
    ]), "0.6.0")
    assert_eq(invalid.error_code, &"invalid_session_id", "путь нельзя внедрить в имя файла")
    return finish()
