extends TestCase


func run() -> Array[String]:
    var session := PlaytestSession.new("PT-001", "abc1234", 1_700_000_000_000, 2)
    var first := session.append(25, 7, &"ui", &"selection", {
        &"kind": &"building",
        &"coord": HexCoord.new(3, 4),
    })
    var second := session.append(40, 7, &"command", &"link_settings", {
        &"result": &"accepted",
        &"cells": [HexCoord.new(1, 2)],
    })
    var dropped := session.append(55, 8, &"ui", &"speed", {&"value": 2})

    assert_eq(first.sequence, 1, "первая запись получает номер 1")
    assert_eq(second.sequence, 2, "вторая запись получает номер 2")
    assert_eq(dropped, null, "переполненный буфер не растёт")
    assert_eq(session.dropped_entries, 1, "потерянная запись учитывается")

    session.finish(&"completed", 1000, 100)
    var encoded := session.to_dictionary()
    assert_eq(encoded["schema_version"], 1, "схема версии 1")
    assert_eq(
        encoded["entries"][0]["payload"]["coord"],
        {"q": 3, "r": 4},
        "HexCoord сериализуется"
    )
    assert_eq(
        encoded["entries"][1]["payload"]["result"],
        "accepted",
        "StringName сериализуется"
    )
    assert_eq(encoded["outcome"], "completed", "исход сохраняется")
    assert_true(session.is_finished(), "сессия завершена")
    var restored := PlaytestSession.from_dictionary(encoded)
    assert_eq(restored.to_dictionary(), encoded, "сессия восстанавливается без потери данных")
    return finish()
