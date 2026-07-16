# Этап 6A: инструментированный плейтест — план реализации

> **Для agentic workers:** REQUIRED SUB-SKILL: используйте `superpowers:subagent-driven-development` (рекомендуется) или `superpowers:executing-plans`, выполняйте задачи по одной и отмечайте шаги через `- [x]`.

**Цель:** добавить не влияющую на симуляцию локальную запись плейтеста, автоматический русский отчёт и воспроизводимый технический контур для пяти слепых сессий новых игроков.

**Архитектура:** новый модуль `src/playtest/` подписывается на сигналы прикладных контроллеров и читает готовые снимки `SimulationState`, но никогда не записывает данные обратно в симуляцию. Сессия хранит ограниченную JSON-совместимую временную шкалу; отдельные анализатор, каталог подписей, writer и storage строят отчёт и сохраняют чередующиеся контрольные копии. `main.gd` создаёт модуль только при явном аргументе `--playtest-session=...`, поэтому обычный игровой путь не получает новых подписок и тиковых вызовов.

**Технологии:** Godot 4.6.2, GDScript 4, `FileAccess`, `DirAccess`, JSON, существующий `TestCase`, headless Godot, Bash для локального launcher'а.

## Глобальные ограничения

- Русский — исходный язык документов и отчёта; пользовательские строки также имеют английское значение.
- `SimulationState` остаётся единственным источником игровой истины.
- Запись не входит в replay-хеш, не изменяет команды, тики, назначения, запасы и события симуляции.
- Режим записи включается только аргументом `--playtest-session=PT-XXX`.
- Один буфер содержит не больше 4096 записей, один итоговый JSON — не больше 1 МБ.
- Контрольная запись выполняется при смене фазы и не чаще одного раза в 60 секунд.
- Постоянная видеозапись и автоматические снимки экрана не добавляются.
- Накладные расходы включённого recorder'а на одинаковом headless-прогоне — не более 3%; выключенного пути — в пределах 1% измерительного шума.
- Активное окно остаётся ограничено 30 FPS, пауза — 10 FPS.
- Новые игровые правила, баланс и художественные ассеты не входят в 6A.
- После реализации 6A нельзя переходить к настройке темпа или пиксель-арту до результатов слепого плейтеста и отдельного плана.

---

## Карта файлов

### Новый модуль `src/playtest/`

- `playtest_value_encoder.gd` — рекурсивно переводит значения GDScript в стабильные JSON-совместимые данные.
- `playtest_entry.gd` — одна неизменяемая запись временной шкалы.
- `playtest_session.gd` — метаданные, ограниченный буфер, состояние завершения и сериализация сессии.
- `playtest_recorder.gd` — событийный сбор UI-действий и релевантных снимков состояния.
- `playtest_milestone_analyzer.gd` — вычисляет вехи, бездействие, путь воды и кандидатов на устранённые узкие места.
- `playtest_report_catalog.gd` — отдельный русско-английский словарь подписей отчёта.
- `playtest_report_writer.gd` — строит JSON и русскоязычный Markdown без доступа к файловой системе.
- `playtest_storage.gd` — создаёт каталог, чередует две контрольные копии и сохраняет уникальные финальные файлы.
- `playtest_launch_options.gd` — разбирает и валидирует пользовательские аргументы запуска.

### Изменяемый прикладной слой

- `src/app/simulation_controller.gd` — сигналы фактической паузы и скорости.
- `src/app/tool_controller.gd` — сигнал смены инструмента.
- `src/app/hud_controller.gd` — сигналы результата команды и переключения диагностического слоя.
- `src/app/main.gd` — условное создание recorder'а, подписки, checkpoint и завершение.
- `project.godot` — версия прототипа `0.6.0-playtest`.
- `localization/game.csv` — локализованные сообщения технического режима.

### Скрипты, тесты и документы

- `scripts/run_playtest.sh` — воспроизводимый запуск с идентификатором и текущим Git SHA.
- `scripts/profile_playtest_recorder.gd` — сравнительный headless-профиль.
- `tests/unit/test_playtest_session.gd`
- `tests/unit/test_playtest_recorder.gd`
- `tests/unit/test_playtest_milestone_analyzer.gd`
- `tests/unit/test_playtest_report_writer.gd`
- `tests/unit/test_playtest_launch_options.gd`
- `tests/integration/test_stage6_playtest_integration.gd`
- `tests/scenarios/test_stage6_playtest_determinism.gd`
- `docs/playtests/observer-guide.md`
- `docs/playtests/session-notes-template.md`
- `docs/playtests/summary-template.md`
- `docs/stages/06-playtest-and-art-pass.md`
- `README.md`

---

### Задача 1: JSON-совместимая модель сессии

**Файлы:**

- Создать: `src/playtest/playtest_value_encoder.gd`
- Создать: `src/playtest/playtest_entry.gd`
- Создать: `src/playtest/playtest_session.gd`
- Создать: `tests/unit/test_playtest_session.gd`

**Интерфейсы:**

- Создаёт: `PlaytestValueEncoder.encode(value: Variant) -> Variant`.
- Создаёт: `PlaytestEntry.new(sequence, elapsed_ms, tick, category, code, payload)`, `to_dictionary() -> Dictionary` и `from_dictionary(data: Dictionary) -> PlaytestEntry`.
- Создаёт: `PlaytestSession.new(id, build_revision, started_unix_ms, max_entries = 4096)`.
- Создаёт: `PlaytestSession.append(elapsed_ms, tick, category, code, payload) -> PlaytestEntry`.
- Создаёт: `PlaytestSession.finish(outcome, elapsed_ms, tick) -> void`, `is_finished() -> bool`, `to_dictionary() -> Dictionary`, `from_dictionary(data: Dictionary) -> PlaytestSession`.
- Не зависит от runner'а, контроллеров, файловой системы и локализации.

- [ ] **Шаг 1: написать падающий тест модели и ограничения буфера**

```gdscript
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
    assert_eq(encoded["entries"][0]["payload"]["coord"], {"q": 3, "r": 4}, "HexCoord сериализуется")
    assert_eq(encoded["entries"][1]["payload"]["result"], "accepted", "StringName сериализуется")
    assert_eq(encoded["outcome"], "completed", "исход сохраняется")
    assert_true(session.is_finished(), "сессия завершена")
    var restored := PlaytestSession.from_dictionary(encoded)
    assert_eq(restored.to_dictionary(), encoded, "сессия восстанавливается без потери данных")
    return finish()
```

- [ ] **Шаг 2: запустить тесты и подтвердить ожидаемое падение**

Запуск:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://tests/run_tests.gd
```

Ожидание: `test_playtest_session.gd` не компилируется, потому что `PlaytestSession` ещё не определён; общий запуск завершается кодом 1.

- [ ] **Шаг 3: реализовать encoder, entry и session**

`playtest_value_encoder.gd` должен рекурсивно сортировать ключи словаря по строковому представлению и поддерживать `StringName`, `HexCoord`, `Array`, `PackedStringArray`, словари, числа, строки, bool и `null`:

```gdscript
class_name PlaytestValueEncoder
extends RefCounted


static func encode(value: Variant) -> Variant:
    if value == null:
        return null
    if value is HexCoord:
        return {"q": value.q, "r": value.r}
    match typeof(value):
        TYPE_STRING_NAME:
            return String(value)
        TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
            var items: Array = []
            for item: Variant in value:
                items.append(encode(item))
            return items
        TYPE_DICTIONARY:
            var source := value as Dictionary
            var keys := source.keys()
            keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
            var result: Dictionary = {}
            for key: Variant in keys:
                result[str(key)] = encode(source[key])
            return result
        TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
            return value
        _:
            return str(value)
```

`PlaytestEntry` хранит поля только из конструктора и возвращает словарь с ключами `sequence`, `elapsed_ms`, `tick`, `category`, `code`, `payload`.

`PlaytestSession` использует `SCHEMA_VERSION := 1`, начинает `_next_sequence` с 1, отклоняет `append()` после завершения или при достижении `max_entries`, увеличивает `dropped_entries`, а `finish()` добавляет исход и конечные время/тик только один раз. `to_dictionary()` возвращает метаданные, `dropped_entries` и массив сериализованных entries. Статические `from_dictionary()` обоих типов проверяют `schema_version == 1`, восстанавливают entries в исходном порядке и устанавливают `_next_sequence` на последний номер плюс один.

- [ ] **Шаг 4: импортировать скрипты и запустить тесты**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://tests/run_tests.gd
```

Ожидание: `TESTS PASSED: 56 suites`.

- [ ] **Шаг 5: зафиксировать модель сессии**

```bash
git add src/playtest tests/unit/test_playtest_session.gd
git commit -m "feat: добавить модель плейтест-сессии"
```

---

### Задача 2: событийный recorder без покадрового опроса

**Файлы:**

- Создать: `src/playtest/playtest_recorder.gd`
- Создать: `tests/unit/test_playtest_recorder.gd`

**Интерфейсы:**

- Потребляет: `PlaytestSession.append(...)`.
- Создаёт: `PlaytestRecorder.configure(session: PlaytestSession, clock_ms: Callable = Callable())`.
- Создаёт: `record_action(tick, category, code, payload = {}) -> void`.
- Создаёт: `record_command(state, intent_code, result_code, payload = {}) -> void`.
- Создаёт: `capture_state(state: SimulationState) -> void`.
- Создаёт: `finish(outcome: StringName, state: SimulationState) -> void`.
- Создаёт сигналы: `checkpoint_requested(session: PlaytestSession)` и `finished(session: PlaytestSession)`.

- [ ] **Шаг 1: написать падающий тест событий и редких снимков**

```gdscript
extends TestCase


func run() -> Array[String]:
    var now := [1000]
    var clock := func() -> int: return now[0]
    var session := PlaytestSession.new("PT-REC", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, clock)
    var state := Stage5TestFactory.scenario_state()

    recorder.record_action(state.tick, &"ui", &"selection", {&"kind": &"building"})
    now[0] = 2100
    recorder.record_command(state, &"link_settings", &"accepted", {&"link_id": 2})

    state.tick = 100
    state.diagnostic_report = DiagnosticReport.new(&"worker_shortage", 10, 2)
    state.events = [SimulationEvent.new(&"cargo_delivered", 100, 1, 9, &"wood")]
    state.events[0].link_id = 2
    recorder.capture_state(state)

    state.tick = 200
    state.scenario_progress.phase = ScenarioProgressState.SITE_PREPARATION
    state.events = []
    recorder.capture_state(state)

    var codes: Array[String] = []
    for entry: PlaytestEntry in session.entries:
        codes.append(String(entry.code))
    assert_true(codes.has("selection"), "выбор записан")
    assert_true(codes.has("link_settings"), "результат команды записан")
    assert_true(codes.has("diagnostic_changed"), "смена диагностики записана")
    assert_true(codes.has("cargo_delivered"), "значимое событие симуляции записано")
    assert_true(codes.has("flow_sample"), "снимок потока записан раз в 100 тиков")
    assert_true(codes.has("scenario_phase_changed"), "смена фазы записана по состоянию")
    assert_true(session.entries.size() < 20, "recorder не пишет каждый тик")
    return finish()
```

- [ ] **Шаг 2: подтвердить падение**

Запустить общий test runner. Ожидание: ошибка определения `PlaytestRecorder`, код 1.

- [ ] **Шаг 3: реализовать recorder**

Recorder хранит начальное значение монотонных часов, последние фазу/диагностику/тик sample и время checkpoint. Разрешённые симуляционные события:

```gdscript
const CAPTURED_EVENTS: Array[StringName] = [
    &"cargo_delivered",
    &"pipe_built",
    &"pipe_removed",
    &"pipe_water_delivered",
    &"production_started",
    &"production_completed",
    &"boiler_cooled",
    &"hammer_struck",
]
const SAMPLE_INTERVAL_TICKS := 100
const CHECKPOINT_INTERVAL_MS := 60_000
```

`capture_state()`:

1. записывает `scenario_phase_changed`, когда `state.scenario_progress.phase` отличается от кэша;
2. записывает `diagnostic_changed` с `code`, `loss_ticks`, `link_id`, `cell_key` при смене `state.diagnostic_report.code`;
3. копирует только события из `CAPTURED_EVENTS`, включая `entity_id`, `job_id`, `resource_id`, `link_id`, `destination_id`, `metric_value`, `cell_key`, `reason`;
4. не чаще раза в 100 тиков добавляет `flow_sample` с `main_throughput_per_minute`, `link_throughput_per_minute`, `completed_jobs`, `manual_water`, `pipe_water`, `diagnostic_code`;
5. при смене фазы или через 60 000 мс после предыдущего checkpoint испускает `checkpoint_requested`;
6. не читает и не изменяет приватные поля runner'а и контроллеров.

`record_command()` сохраняет intent как `code`, а в payload — `result` и безопасно закодированные параметры. `finish()` однократно завершает session и испускает `finished`.

- [ ] **Шаг 4: запустить тесты**

Ожидание: `TESTS PASSED: 57 suites`.

- [ ] **Шаг 5: зафиксировать recorder**

```bash
git add src/playtest/playtest_recorder.gd tests/unit/test_playtest_recorder.gd
git commit -m "feat: записывать события плейтеста"
```

---

### Задача 3: анализ вех, бездействия и кандидатов на улучшение

**Файлы:**

- Создать: `src/playtest/playtest_milestone_analyzer.gd`
- Создать: `tests/unit/test_playtest_milestone_analyzer.gd`

**Интерфейсы:**

- Потребляет: `Array[PlaytestEntry]` и завершённую `PlaytestSession`.
- Создаёт: `analyze(session: PlaytestSession) -> Dictionary`.
- Возвращает ключи `milestones`, `idle_periods`, `water_path`, `command_counts`, `layer_usage`, `bottleneck_candidates`.

- [ ] **Шаг 1: написать падающий тест анализа**

```gdscript
extends TestCase


func run() -> Array[String]:
    var session := PlaytestSession.new("PT-AN", "dev", 0)
    session.append(0, 0, &"state", &"flow_sample", {
        &"diagnostic_code": &"worker_shortage",
        &"main_throughput_per_minute": {&"wood": 2.0},
        &"link_throughput_per_minute": {2: 2.0},
        &"manual_water": 0,
        &"pipe_water": 0,
    })
    session.append(60_000, 600, &"command", &"link_settings", {
        &"result": &"accepted",
        &"link_id": 2,
    })
    session.append(70_000, 700, &"state", &"diagnostic_changed", {&"code": &""})
    session.append(95_000, 950, &"state", &"flow_sample", {
        &"diagnostic_code": &"",
        &"main_throughput_per_minute": {&"wood": 4.0},
        &"link_throughput_per_minute": {2: 4.0},
        &"manual_water": 1,
        &"pipe_water": 8,
    })
    session.append(130_500, 1200, &"ui", &"selection", {&"kind": &"building"})
    session.append(140_000, 1300, &"state", &"scenario_phase_changed", {&"phase": &"completed"})
    session.finish(&"completed", 140_000, 1300)

    var result := PlaytestMilestoneAnalyzer.new().analyze(session)
    assert_eq(result["milestones"]["first_logistics_action_ms"], 60_000, "первая логистическая команда найдена")
    assert_eq(result["water_path"], "mixed", "смешанная вода определена")
    assert_eq(result["command_counts"]["accepted"], 1, "команда учтена")
    assert_eq(result["bottleneck_candidates"].size(), 1, "улучшение связи стало кандидатом")
    assert_true(result["idle_periods"].size() >= 1, "интервал больше 30 секунд найден")
    return finish()
```

- [ ] **Шаг 2: подтвердить падение**

Запустить общий test runner. Ожидание: `PlaytestMilestoneAnalyzer` не определён.

- [ ] **Шаг 3: реализовать детерминированный анализ**

Список осмысленных логистических команд:

```gdscript
const LOGISTICS_ACTIONS: Array[StringName] = [
    &"road_cell", &"depot_cell", &"link_complete", &"link_settings",
    &"dispatch_policy", &"remove_link", &"reset_link",
    &"demolish_depot", &"pipe_build", &"pipe_remove",
]
const IDLE_THRESHOLD_MS := 30_000
const IMPROVEMENT_RATIO := 1.25
const MIN_ABSOLUTE_GAIN := 0.5
const IMPROVEMENT_MIN_TICKS := 300
const IMPROVEMENT_MAX_TICKS := 600
```

Анализатор проходит entries один раз для вех, счётчиков, последнего `flow_sample` и интервалов между `ui`/`command`. Для каждого принятого логистического действия он находит последний sample до действия и первый sample в диапазоне 300–600 тиков после него. Кандидат создаётся только если диагностический код до действия был непустым, после действия исчез или изменился, а поток вырос минимум в 1,25 раза и минимум на 0,5 единицы/мин.

Если у команды есть `link_id`, сравнивается `link_throughput_per_minute[link_id]`; иначе сравнивается сумма `main_throughput_per_minute`. Кандидат содержит `action_code`, `elapsed_ms`, `tick`, `diagnostic_before`, `diagnostic_after`, `throughput_before`, `throughput_after`, `link_id`, `confirmed: false`.

`water_path` равен `manual`, `pipe`, `mixed` или `none` по последнему sample. Анализатор ничего не записывает обратно в session.

- [ ] **Шаг 4: запустить тесты**

Ожидание: `TESTS PASSED: 58 suites`.

- [ ] **Шаг 5: зафиксировать анализатор**

```bash
git add src/playtest/playtest_milestone_analyzer.gd tests/unit/test_playtest_milestone_analyzer.gd
git commit -m "feat: анализировать вехи плейтеста"
```

---

### Задача 4: русский отчёт и отказоустойчивое хранение

**Файлы:**

- Создать: `src/playtest/playtest_report_catalog.gd`
- Создать: `src/playtest/playtest_report_writer.gd`
- Создать: `src/playtest/playtest_storage.gd`
- Создать: `tests/unit/test_playtest_report_writer.gd`

**Интерфейсы:**

- Создаёт: `PlaytestReportCatalog.text(key: StringName, locale: StringName = &"ru") -> String`.
- Создаёт: `PlaytestReportWriter.build_json(session, analysis) -> String`.
- Создаёт: `PlaytestReportWriter.build_markdown(session, analysis, locale = &"ru") -> String`.
- Создаёт: `PlaytestStorage.new(root_path = "user://playtests")`.
- Создаёт: `write_checkpoint(session, json_text) -> Dictionary` и `write_final(session, json_text, markdown_text) -> Dictionary`.
- Создаёт: `load_latest_checkpoint(session_id: String) -> Dictionary` и `clear_checkpoints(session_id: String) -> void`.

- [ ] **Шаг 1: написать падающий тест отчёта и двух checkpoint-слотов**

```gdscript
extends TestCase


func run() -> Array[String]:
    var session := PlaytestSession.new("PT-REPORT", "abc1234", 123)
    session.append(1000, 10, &"command", &"link_settings", {&"result": &"accepted"})
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

    assert_true(json_text.length() > 0, "JSON построен")
    assert_true(JSON.parse_string(json_text) is Dictionary, "JSON разбирается")
    assert_true(markdown.contains("# Отчёт плейтеста PT-REPORT"), "русский заголовок есть")
    assert_true(markdown.contains("## Ответы игрока"), "место для ответов есть")
    assert_true(markdown.contains("## Заметки наблюдателя"), "место для заметок есть")

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
    assert_eq(recovered["data"]["session"]["id"], "PT-REPORT", "восстановлена нужная сессия")
    var final_result := storage.write_final(session, json_text, markdown)
    assert_true(final_result["ok"], "два финальных файла записаны")
    assert_true(FileAccess.file_exists(final_result["json_path"]), "итоговый JSON существует")
    assert_true(FileAccess.file_exists(final_result["markdown_path"]), "итоговый Markdown существует")
    return finish()
```

- [ ] **Шаг 2: подтвердить падение**

Запустить общий test runner. Ожидание: отсутствуют writer/storage, код 1.

- [ ] **Шаг 3: реализовать каталог и writer**

Каталог содержит минимум ключи `report_title`, `summary`, `result`, `duration`, `milestones`, `commands`, `idle`, `diagnostics`, `water_path`, `bottlenecks`, `player_answers`, `observer_notes`, `unknown_event` для `ru` и `en`. Writer не вызывает `tr()`, чтобы язык отчёта не зависел от текущей локали игры.

JSON имеет корень:

```gdscript
{
    "session": session.to_dictionary(),
    "analysis": PlaytestValueEncoder.encode(analysis),
}
```

Markdown выводит исход, реальную продолжительность, конечный тик, потерянные entries, вехи, accepted/rejected, интервалы бездействия, использование слоёв, путь воды, кандидатов с флагом `confirmed: false`, а в конце дословно создаёт три поля ответов игрока и свободное поле наблюдателя. Неизвестный код отображается как `Неизвестное событие: <code>`.

- [ ] **Шаг 4: реализовать storage**

Storage глобализует root через `ProjectSettings.globalize_path()`, создаёт каталог через `DirAccess.make_dir_recursive_absolute()` и возвращает словарь `{ "ok": bool, "error": String, ...paths }` вместо assert.

Checkpoint-файлы называются `<session>.checkpoint-a.json` и `<session>.checkpoint-b.json`; каждый вызов меняет слот, поэтому предыдущая копия не перезаписывается текущей. `load_latest_checkpoint()` разбирает оба файла, игнорирует повреждённый JSON и выбирает копию с наибольшим номером последней записи. `clear_checkpoints()` удаляет только эти два точно вычисленных файла после успешного финального сохранения. Финальные `<session>.json` и `<session>-report.ru.md` уникальны: если любой уже существует, метод возвращает `ok: false`, не меняя файлы. После `store_string()` проверяется `file.get_error()`. Размер JSON проверяется по `json_text.to_utf8_buffer().size()` и отклоняется при превышении 1 048 576 байт.

- [ ] **Шаг 5: запустить тесты**

Ожидание: `TESTS PASSED: 59 suites`.

- [ ] **Шаг 6: зафиксировать отчётность**

```bash
git add src/playtest tests/unit/test_playtest_report_writer.gd
git commit -m "feat: формировать русский отчёт плейтеста"
```

---

### Задача 5: явный запуск и подключение к приложению

**Файлы:**

- Создать: `src/playtest/playtest_launch_options.gd`
- Создать: `tests/unit/test_playtest_launch_options.gd`
- Создать: `tests/integration/test_stage6_playtest_integration.gd`
- Создать: `scripts/run_playtest.sh`
- Изменить: `src/app/simulation_controller.gd`
- Изменить: `src/app/tool_controller.gd`
- Изменить: `src/app/hud_controller.gd`
- Изменить: `src/app/main.gd`
- Изменить: `project.godot`
- Изменить: `localization/game.csv`
- Изменить: `tests/unit/test_localization.gd`

**Интерфейсы:**

- Создаёт: `PlaytestLaunchOptions.parse(args: PackedStringArray, fallback_build: String) -> PlaytestLaunchOptions`.
- Создаёт свойства `enabled`, `session_id`, `build_revision`, `error_code`.
- Создаёт сигналы `SimulationController.pause_changed(bool)`, `speed_changed(int)`.
- Создаёт сигнал `ToolController.mode_changed(StringName)`.
- Создаёт сигналы `HUDController.intent_resolved(intent_code, result_code, payload)` и `layer_visibility_changed(layer, visible)`.
- `main.gd` создаёт recorder только при `options.enabled and options.error_code.is_empty()`.

- [ ] **Шаг 1: написать падающий тест аргументов**

```gdscript
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

    var invalid := PlaytestLaunchOptions.parse(PackedStringArray([
        "--playtest-session=../bad",
    ]), "0.6.0")
    assert_eq(invalid.error_code, &"invalid_session_id", "путь нельзя внедрить в имя файла")
    return finish()
```

- [ ] **Шаг 2: написать падающий интеграционный тест сигналов**

```gdscript
extends TestCase


func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    assert_eq(instance.get_playtest_recorder(), null, "обычная игра не создаёт recorder")

    var runner: SimulationRunner = instance.get_runner()
    var hash_before := StateHasher.new().hash_state(runner.state)
    var session := PlaytestSession.new("PT-INT", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, func() -> int: return runner.state.tick * 100)
    var storage := PlaytestStorage.new("user://playtest-tests/PT-INT-%d" % Time.get_ticks_usec())
    instance.configure_playtest_for_test(recorder, storage)
    assert_eq(StateHasher.new().hash_state(runner.state), hash_before, "подключение не меняет состояние")

    instance.get_hud_controller().set_layer_visible(&"routes", true)
    instance.get_hud_controller().set_speed_multiplier(2)
    instance.call("_begin_road")
    instance.get_hud_controller().submit_intent({
        &"code": &"link_settings",
        &"link_id": 1,
        &"quota": 2,
        &"priority": 3,
        &"dispatch_enabled": true,
    })

    var codes: Array[String] = []
    for entry: PlaytestEntry in session.entries:
        codes.append(String(entry.code))
    assert_true(codes.has("layer_visibility"), "слой записан")
    assert_true(codes.has("speed"), "скорость записана")
    assert_true(codes.has("road"), "инструмент записан")
    assert_true(codes.has("link_settings"), "результат команды записан")
    instance.free()
    return finish()
```

Тест проверяет четыре прикладных источника событий и отдельно сравнивает хеш до и сразу после подключения recorder'а. Результат самой `link_settings` может быть принят или отклонён текущими правилами; временная шкала обязана сохранить оба варианта.

- [ ] **Шаг 3: запустить тесты и подтвердить падение**

Ожидание: два новых набора не компилируются, код 1.

- [ ] **Шаг 4: реализовать launch options и сигналы контроллеров**

Допустимый session id: 1–32 символа из `A-Z`, `a-z`, `0-9`, `_`, `-`. Пустой `--playtest-build` использует `application/config/version`.

Контроллеры испускают сигнал только после фактического успешного изменения. `HUDController.submit_intent()` испускает `intent_resolved` и для отклонения очередью, и после `flush_commands`; payload содержит исходный intent без объектов runner'а. `set_layer_visible()` испускает сигнал только при `true` результате.

- [ ] **Шаг 5: подключить recorder в `main.gd`**

Добавить поля recorder/storage/writer/analyzer и методы:

```gdscript
func get_playtest_recorder() -> PlaytestRecorder:
    return _playtest_recorder


func configure_playtest_for_test(recorder: PlaytestRecorder, storage: PlaytestStorage) -> void:
    _attach_playtest(recorder, storage)


func _configure_playtest_from_args() -> void:
    var fallback := ProjectSettings.get_setting("application/config/version", "dev") as String
    var options := PlaytestLaunchOptions.parse(OS.get_cmdline_user_args(), fallback)
    if not options.error_code.is_empty():
        push_error(tr(StringName("playtest.error.%s" % options.error_code)))
        return
    if not options.enabled:
        return
    var storage := PlaytestStorage.new()
    var recovered := storage.load_latest_checkpoint(options.session_id)
    if recovered.get("ok", false) as bool:
        _finalize_recovered_session(recovered["data"] as Dictionary, storage)
        push_error(tr(&"playtest.error.recovered_interrupted"))
        return
    var session := PlaytestSession.new(
        options.session_id,
        options.build_revision,
        int(Time.get_unix_time_from_system() * 1000.0)
    )
    var recorder := PlaytestRecorder.new()
    recorder.configure(session)
    _attach_playtest(recorder, storage)
```

`_configure_playtest_from_args()` вызывается в конце `_ready()` после `_connect_ui()`. `_attach_playtest()` соединяет selection, tool, pause, speed, layer, intent, checkpoint и finished и печатает глобализованный каталог `PLAYTEST_OUTPUT=<path>`. `_on_state_changed()` вызывает `capture_state()` только если recorder существует. При `ScenarioProgressState.COMPLETED` вызывает `finish(&"completed", state)`. `_exit_tree()` завершает незавершённую сессию как `aborted`. Checkpoint-callback запускает analyzer и writer, затем передаёт JSON в `storage.write_checkpoint()`. Финальный callback строит оба формата, вызывает `write_final()` и только после успеха — `clear_checkpoints()`. Ошибка storage выводится через локализованный ключ, но не останавливает игру.

`_finalize_recovered_session()` восстанавливает `PlaytestSession` из `data["session"]`, завершает её как `aborted` на последних elapsed/tick, повторно строит analysis и два отчёта, сохраняет их под исходным ID и очищает checkpoint только после успеха. В этом запуске новая сессия не начинается: наблюдатель должен выбрать следующий ID, поэтому данные аварийного прогона не смешиваются с новой трассой.

- [ ] **Шаг 6: добавить launcher и локализацию**

`project.godot`:

```ini
config/version="0.6.0-playtest"
```

`scripts/run_playtest.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_ID="${1:?Использование: scripts/run_playtest.sh PT-001}"
BUILD_REVISION="$(git -C "$PROJECT_DIR" rev-parse --short HEAD)"

exec "$GODOT_BIN" --path "$PROJECT_DIR" -- \
    "--playtest-session=$SESSION_ID" \
    "--playtest-build=$BUILD_REVISION"
```

Добавить RU/EN ключи `playtest.error.invalid_session_id`, `playtest.error.storage_write`, `playtest.error.report_too_large`, `playtest.error.recovered_interrupted`. Расширить `test_localization.gd` этими ключами.

- [ ] **Шаг 7: импортировать и запустить тесты**

Ожидание: `TESTS PASSED: 61 suites`.

- [ ] **Шаг 8: зафиксировать подключение**

```bash
git add project.godot localization/game.csv scripts/run_playtest.sh src/app src/playtest tests
git commit -m "feat: подключить режим инструментированного плейтеста"
```

---

### Задача 6: детерминизм, производительность и русские документы

**Файлы:**

- Создать: `tests/scenarios/test_stage6_playtest_determinism.gd`
- Создать: `scripts/profile_playtest_recorder.gd`
- Создать: `docs/playtests/observer-guide.md`
- Создать: `docs/playtests/session-notes-template.md`
- Создать: `docs/playtests/summary-template.md`
- Создать: `docs/stages/06-playtest-and-art-pass.md`
- Изменить: `README.md`

**Интерфейсы:**

- Профиль печатает одну строку `STAGE6_RECORDER baseline_ms=<n> recorder_ms=<n> overhead=<x.xx>` и завершает процесс кодом 1 при `overhead > 1.03`.
- Документы не утверждают, что пять пользовательских сессий уже проведены.

- [ ] **Шаг 1: написать сценарный тест изоляции**

```gdscript
extends TestCase


func run() -> Array[String]:
    var baseline := Stage5TestFactory.full_runner(true)
    var observed := Stage5TestFactory.full_runner(true)
    var session := PlaytestSession.new("PT-DET", "dev", 0)
    var recorder := PlaytestRecorder.new()
    recorder.configure(session, func() -> int: return observed.state.tick * 100)

    for _index in 1000:
        var baseline_hash := baseline.step()
        var observed_hash := observed.step()
        recorder.capture_state(observed.state)
        assert_eq(observed_hash, baseline_hash, "recorder не меняет хеш тика")

    assert_eq(StateHasher.new().hash_state(observed.state), StateHasher.new().hash_state(baseline.state), "итоговые состояния совпадают")
    assert_true(session.entries.size() > 0, "внешняя временная шкала заполнена")
    return finish()
```

- [ ] **Шаг 2: запустить тесты**

Ожидание: `TESTS PASSED: 62 suites`.

- [ ] **Шаг 3: реализовать сравнительный профиль**

`profile_playtest_recorder.gd` расширяет `SceneTree`, выполняет пять пар прогонов по 2000 тиков с `Stage5TestFactory.full_runner(false)`. В каждой паре порядок baseline/recorder чередуется. В recorder-прогоне вызывается `capture_state()` после каждого `step()`. Из пяти значений берётся медиана, overhead считается как `float(recorder_ms) / maxf(float(baseline_ms), 1.0)`. При превышении 1.03 скрипт печатает ошибку и вызывает `quit(1)`.

Запуск:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://scripts/profile_playtest_recorder.gd
```

Ожидание: строка `STAGE6_RECORDER ... overhead=<значение не выше 1.03>`, код 0.

- [ ] **Шаг 4: написать инструкцию наблюдателя**

`observer-guide.md` фиксирует:

1. участник раньше не видел проект;
2. наблюдатель запускает `./scripts/run_playtest.sh PT-001`;
3. произносится только утверждённая цель;
4. подсказки запрещены, кроме технической неисправности;
5. основное окно 20 минут, диагностическое продолжение до 30;
6. после сессии задаются ровно три утверждённых вопроса;
7. техническое вмешательство делает сессию недействительной;
8. между пятью базовыми сессиями сборка не меняется;
9. путь к `user://playtests/` выводится в Godot log при старте;
10. raw JSON не коммитится без проверки, сводка обезличивается.

`session-notes-template.md` содержит ID, build SHA, времена вех, вмешательства, три ответа и заметки. `summary-template.md` содержит таблицу пяти сессий, расчёт 4/5, медиану, повторяющиеся проблемы и решение по следующему шлюзу.

`docs/stages/06-playtest-and-art-pass.md` описывает только реализованную инфраструктуру 6A и явно указывает статус «ожидаются пять слепых сессий». README получает команду запуска и путь к русскому отчёту.

- [ ] **Шаг 5: выполнить полный gate**

```bash
./scripts/check_project.sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://scripts/profile_playtest_recorder.gd
git diff --check
```

Ожидание: `TESTS PASSED: 62 suites`, `Проверка проекта завершена успешно`, overhead ≤ 1.03, пустой вывод `git diff --check`.

- [ ] **Шаг 6: зафиксировать проверки и документы**

```bash
git add README.md docs scripts/profile_playtest_recorder.gd tests/scenarios/test_stage6_playtest_determinism.gd
git commit -m "test: подготовить технический gate плейтеста"
```

---

### Задача 7: технический прогон и передача сборки на пять сессий

**Файлы:**

- Изменить при обнаружении фактических расхождений: `docs/stages/06-playtest-and-art-pass.md`
- Создать локально, не коммитить: `user://playtests/PT-TECH.json`
- Создать локально, не коммитить: `user://playtests/PT-TECH-report.ru.md`

**Интерфейсы:**

- Не создаёт новых игровых механик.
- Выход: проверенная сборка и точный handoff для сессий `PT-001`…`PT-005` на одном Git SHA.

- [ ] **Шаг 1: запустить техническую сессию в установленном Godot**

```bash
./scripts/run_playtest.sh PT-TECH
```

Вручную выбрать здание, включить маршруты, сменить скорость, изменить одну связь, построить доступный сегмент инфраструктуры, дождаться checkpoint и штатно закрыть игру. Не использовать эту сессию как пользовательский результат.

- [ ] **Шаг 2: проверить два финальных файла**

Открыть путь, напечатанный при запуске. Проверить:

- JSON разбирается и содержит `schema_version: 1`;
- `build_revision` совпадает с `git rev-parse --short HEAD`;
- временная шкала содержит selection, layer, speed, command, phase и flow samples;
- Markdown полностью на русском, не содержит сырых ключей;
- размер JSON меньше 1 048 576 байт;
- повторный запуск с `PT-TECH` не перезаписывает существующий результат.

- [ ] **Шаг 3: проверить выключенный путь**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
```

Ожидание: recorder не создаётся, новых файлов нет, сценарий и нагрузка соответствуют грейбокс-базе этапа 5.

- [ ] **Шаг 4: повторить полный gate после визуального прогона**

```bash
./scripts/check_project.sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://scripts/profile_playtest_recorder.gd
git status --short
```

Ожидание: 62 набора проходят, overhead ≤ 1.03, рабочее дерево чистое либо содержит только намеренное уточнение документа.

- [ ] **Шаг 5: зафиксировать фактическое изменение документа либо пропустить коммит**

```bash
git add docs/stages/06-playtest-and-art-pass.md
git commit -m "docs: уточнить технический прогон этапа 6A"
```

Если расхождений нет, отдельный коммит не создаётся.

- [ ] **Шаг 6: отправить реализацию и зафиксировать SHA плейтест-сборки**

```bash
git push origin main
git rev-parse --short HEAD
```

Записать полученный SHA в `docs/playtests/summary-template.md` только при создании фактической копии сводного отчёта для группы. Все пять сессий `PT-001`…`PT-005` запускаются на этом SHA.

---

## Шлюз после 6A

После технической готовности 6A работа останавливается на сборе внешних данных. Ассистент не может засчитать собственное прохождение как тест нового игрока.

Дальнейший порядок:

1. провести пять слепых сессий на одном SHA;
2. заполнить обезличенную русскую сводку;
3. проверить критерии 4 из 5 и медиану;
4. если понятность не подтверждена — согласовать только изменения взаимодействия и составить отдельный план исправлений;
5. если понятность подтверждена, но темп не попал в 15–20 минут — согласовать числовые варианты и составить план настройки;
6. только после механического шлюза создать и согласовать качественный пиксель-арт styleframe 1280×720;
7. после утверждения styleframe составить отдельный план производства и интеграции ассетов.

Такой порядок не уменьшает этап 6: он не позволяет заранее закодировать баланс и художественные решения, которые должны опираться на реальные плейтесты.
