class_name PlaytestReportCatalog
extends RefCounted

const LABELS := {
    "ru": {
        "report_title": "Отчёт плейтеста {id}",
        "summary": "Сводка",
        "build": "Сборка",
        "result": "Результат",
        "duration": "Реальное время",
        "paused": "Время на паузе",
        "end_tick": "Конечный тик",
        "dropped_entries": "Потерянные записи",
        "milestones": "Вехи",
        "commands": "Команды",
        "accepted": "Принято",
        "rejected": "Отклонено",
        "idle": "Периоды бездействия",
        "speeds": "Использование скорости",
        "phase_durations": "Длительность фаз",
        "layers": "Диагностические слои",
        "diagnostics": "Измеренные причины остановки",
        "difficulties": "Предварительная классификация затруднений",
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
        "unknown_value": "Неизвестное значение: {code}",
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
        "paused": "Paused time",
        "end_tick": "Final tick",
        "dropped_entries": "Dropped entries",
        "milestones": "Milestones",
        "commands": "Commands",
        "accepted": "Accepted",
        "rejected": "Rejected",
        "idle": "Idle periods",
        "speeds": "Speed usage",
        "phase_durations": "Phase durations",
        "layers": "Diagnostic layers",
        "diagnostics": "Measured stop reasons",
        "difficulties": "Preliminary difficulty classification",
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
        "unknown_value": "Unknown value: {code}",
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

const VALUES := {
    "ru": {
        "layer.links": "Связи",
        "layer.routes": "Маршруты",
        "layer.load": "Загрузка",
        "layer.utilities": "Инженерные сети",
        "action.road_cell": "Строительство дороги",
        "action.depot_cell": "Строительство склада",
        "action.link_complete": "Создание грузовой связи",
        "action.link_settings": "Настройка грузовой связи",
        "action.dispatch_policy": "Политика отгрузки",
        "action.remove_link": "Удаление грузовой связи",
        "action.reset_link": "Возврат автоматического маршрута",
        "action.demolish_depot": "Разбор склада",
        "action.pipe_build": "Строительство водопровода",
        "action.pipe_remove": "Разбор водопровода",
        "reason.worker_shortage": "Не хватает работников",
        "reason.route_conflict": "Конфликт маршрутов",
        "reason.relay_backlog": "Перевалочный склад переполнен",
        "phase.observation": "Наблюдение",
        "phase.site_preparation": "Подготовка промышленной площадки",
        "phase.boiler_supply": "Снабжение котла",
        "phase.warming": "Устойчивый прогрев котла",
        "phase.first_strike": "Подготовка первого удара",
        "phase.completed": "Сценарий завершён",
        "difficulty.observer_review": "Требует классификации наблюдателем",
    },
    "en": {
        "layer.links": "Links",
        "layer.routes": "Routes",
        "layer.load": "Load",
        "layer.utilities": "Utilities",
        "action.road_cell": "Road construction",
        "action.depot_cell": "Depot construction",
        "action.link_complete": "Logistics link creation",
        "action.link_settings": "Logistics link settings",
        "action.dispatch_policy": "Dispatch policy",
        "action.remove_link": "Logistics link removal",
        "action.reset_link": "Automatic route reset",
        "action.demolish_depot": "Depot demolition",
        "action.pipe_build": "Water pipe construction",
        "action.pipe_remove": "Water pipe removal",
        "reason.worker_shortage": "Worker shortage",
        "reason.route_conflict": "Route conflict",
        "reason.relay_backlog": "Relay depot backlog",
        "phase.observation": "Observation",
        "phase.site_preparation": "Industrial site preparation",
        "phase.boiler_supply": "Boiler supply",
        "phase.warming": "Steady boiler warming",
        "phase.first_strike": "First strike preparation",
        "phase.completed": "Scenario completed",
        "difficulty.observer_review": "Requires observer classification",
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


static func value(
    group: String,
    code: String,
    locale: StringName = &"ru"
) -> String:
    if code.is_empty():
        return text(&"none", locale)
    var locale_key := String(locale)
    var selected := VALUES.get(locale_key, VALUES["ru"]) as Dictionary
    var key := "%s.%s" % [group, code]
    if selected.has(key):
        return selected[key] as String
    return text(&"unknown_value", locale).format({"code": code})


static func is_known_event(code: StringName) -> bool:
    return String(code) in KNOWN_EVENTS


static func unknown_event(code: StringName, locale: StringName = &"ru") -> String:
    return text(&"unknown_event", locale).format({"code": String(code)})
