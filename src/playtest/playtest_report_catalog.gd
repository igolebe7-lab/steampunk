class_name PlaytestReportCatalog
extends RefCounted

const LABELS := {
    "ru": {
        "report_title": "Отчёт плейтеста {id}",
        "summary": "Сводка",
        "build": "Сборка",
        "result": "Результат",
        "duration": "Реальное время",
        "end_tick": "Конечный тик",
        "dropped_entries": "Потерянные записи",
        "milestones": "Вехи",
        "commands": "Команды",
        "accepted": "Принято",
        "rejected": "Отклонено",
        "idle": "Периоды бездействия",
        "layers": "Диагностические слои",
        "water_path": "Путь воды",
        "bottlenecks": "Кандидаты на устранённые узкие места",
        "unknown_events": "Неизвестные события",
        "player_answers": "Ответы игрока",
        "question_1": "Что сильнее всего задерживало производство?",
        "question_2": "Какое изменение больше всего помогло?",
        "question_3": "Зачем здесь нужен водопровод?",
        "observer_notes": "Заметки наблюдателя",
        "none": "Нет",
        "unknown_event": "Неизвестное событие: {code}",
        "outcome.completed": "Сценарий завершён",
        "outcome.aborted": "Сессия прервана",
        "outcome.unknown": "Исход не определён",
        "water.none": "Вода не доставлена",
        "water.manual": "Ручная доставка",
        "water.pipe": "Водопровод",
        "water.mixed": "Смешанный путь",
        "confirmed": "Требует подтверждения наблюдателем",
    },
    "en": {
        "report_title": "Playtest Report {id}",
        "summary": "Summary",
        "build": "Build",
        "result": "Result",
        "duration": "Elapsed time",
        "end_tick": "Final tick",
        "dropped_entries": "Dropped entries",
        "milestones": "Milestones",
        "commands": "Commands",
        "accepted": "Accepted",
        "rejected": "Rejected",
        "idle": "Idle periods",
        "layers": "Diagnostic layers",
        "water_path": "Water path",
        "bottlenecks": "Bottleneck candidates",
        "unknown_events": "Unknown events",
        "player_answers": "Player answers",
        "question_1": "What delayed production the most?",
        "question_2": "Which change helped the most?",
        "question_3": "Why is the water pipe useful?",
        "observer_notes": "Observer notes",
        "none": "None",
        "unknown_event": "Unknown event: {code}",
        "outcome.completed": "Scenario completed",
        "outcome.aborted": "Session aborted",
        "outcome.unknown": "Outcome unknown",
        "water.none": "No water delivered",
        "water.manual": "Manual delivery",
        "water.pipe": "Water pipe",
        "water.mixed": "Mixed path",
        "confirmed": "Requires observer confirmation",
    },
}

const MILESTONES := {
    "ru": {
        "first_logistics_action_ms": "Первое изменение логистики",
        "first_inspector_ms": "Первое использование инспектора",
        "first_flow_improvement_ms": "Первое измеримое улучшение потока",
        "phase_observation_ms": "Начало наблюдения",
        "phase_site_preparation_ms": "Начало подготовки площадки",
        "phase_boiler_supply_ms": "Начало снабжения котла",
        "phase_warming_ms": "Начало прогрева",
        "phase_first_strike_ms": "Готовность к первому удару",
        "phase_completed_ms": "Первый удар молота",
    },
    "en": {
        "first_logistics_action_ms": "First logistics change",
        "first_inspector_ms": "First inspector use",
        "first_flow_improvement_ms": "First measured flow improvement",
        "phase_observation_ms": "Observation started",
        "phase_site_preparation_ms": "Site preparation started",
        "phase_boiler_supply_ms": "Boiler supply started",
        "phase_warming_ms": "Warming started",
        "phase_first_strike_ms": "First strike unlocked",
        "phase_completed_ms": "First hammer strike",
    },
}

const KNOWN_EVENTS: Array[String] = [
    "selection", "pause", "speed", "inspect", "road", "depot",
    "link_origin", "link_destination", "layer_visibility",
    "road_cell", "depot_cell", "link_complete", "link_settings",
    "dispatch_policy", "remove_link", "reset_link", "demolish_depot",
    "pipe_build", "pipe_remove", "scenario_phase_changed",
    "diagnostic_changed", "flow_sample", "cargo_delivered", "pipe_built",
    "pipe_removed", "pipe_water_delivered", "production_started",
    "production_completed", "boiler_cooled", "hammer_struck",
]


static func text(key: StringName, locale: StringName = &"ru") -> String:
    var locale_key := String(locale)
    var selected := LABELS.get(locale_key, LABELS["ru"]) as Dictionary
    if selected.has(String(key)):
        return selected[String(key)] as String
    return (LABELS["ru"] as Dictionary).get(String(key), String(key)) as String


static func milestone(key: String, locale: StringName = &"ru") -> String:
    var locale_key := String(locale)
    var selected := MILESTONES.get(locale_key, MILESTONES["ru"]) as Dictionary
    return selected.get(key, key) as String


static func is_known_event(code: StringName) -> bool:
    return String(code) in KNOWN_EVENTS


static func unknown_event(code: StringName, locale: StringName = &"ru") -> String:
    return text(&"unknown_event", locale).format({"code": String(code)})
