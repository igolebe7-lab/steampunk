# Этап 2: детерминированная симуляция — план реализации

> **Для agentic workers:** REQUIRED SUB-SKILL: использовать `superpowers:executing-plans` и выполнять задачи последовательно через TDD. Шаги отслеживаются checkbox-разметкой.

**Цель:** создать независимое от кадров ядро симуляции с фиксированными тиками, Resource-определениями, атомарной загрузкой сценария, командами и доказуемо стабильным SHA-256 состояния.

**Архитектура:** авторские данные хранятся в неизменяемых Godot Resources. Изменяемый мир находится в `SimulationState`; `SimulationRunner` применяет команды в стабильном порядке и хэширует завершённое состояние. Представление этапа 1 не получает право менять модель напрямую.

**Технологии:** Godot 4.6.2, статически типизированный GDScript, `.tres`, собственный headless-раннер, SHA-256 через `HashingContext`, Git.

## Глобальные ограничения

- Пользовательские документы и строки — на русском; технические идентификаторы — на английском.
- Базовая локаль — `ru`, строки вызываются через ключи локализации.
- Симуляция не использует `Node`, `_process()`, frame delta, системное время или порядок Dictionary.
- Базовая частота — 10 тиков в секунду; тесты выполняют тики явно.
- Этап не добавляет рабочих, маршруты, доставку, производство или HUD управления временем.

---

### Задача 1: Resource-определения и каталог

**Файлы:**
- Создать: `src/simulation/definitions/resource_def.gd`
- Создать: `src/simulation/definitions/building_def.gd`
- Создать: `src/simulation/definitions/definition_catalog.gd`
- Создать: `data/resources/{wood,iron,coal,water}.tres`
- Создать: `data/buildings/{transfer_depot,boiler,steam_hammer}.tres`
- Создать: `data/catalog.tres`
- Создать: `tests/unit/test_definition_catalog.gd`
- Изменить: `localization/game.csv`
- Изменить: `tests/integration/test_project_configuration.gd`

**Интерфейсы:**
- `ResourceDef`: `id`, `display_name_key`, `color`.
- `BuildingDef`: `id`, `display_name_key`, `footprint`, `inventory_capacity`.
- `DefinitionCatalog.validate() -> Array[StringName]`, `get_resource(id)`, `get_building(id)`.

- [ ] **Шаг 1: написать падающий тест каталога**

```gdscript
extends TestCase

func run() -> Array[String]:
    var catalog := load("res://data/catalog.tres") as DefinitionCatalog
    assert_true(catalog != null, "каталог определений должен загружаться")
    if catalog == null:
        return finish()
    assert_eq(catalog.validate(), [], "базовый каталог должен быть корректным")
    assert_eq(catalog.resources.size(), 4, "каталог должен содержать четыре ресурса")
    assert_eq(catalog.buildings.size(), 3, "каталог должен содержать три здания")
    assert_eq(catalog.get_resource(&"wood").display_name_key, &"resource.wood.name", "дерево должно иметь ключ названия")
    assert_eq(catalog.get_building(&"steam_hammer").footprint.size(), 3, "паровой молот должен занимать три гекса")

    var duplicate := DefinitionCatalog.new()
    duplicate.resources = [catalog.resources[0], catalog.resources[0]]
    assert_true(duplicate.validate().has(&"duplicate_resource_id"), "повтор ID ресурса должен отклоняться")
    return finish()
```

- [ ] **Шаг 2: запустить тест и подтвердить отсутствие классов/каталога**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

- [ ] **Шаг 3: реализовать классы определений**

```gdscript
# resource_def.gd
class_name ResourceDef
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var color: Color = Color.WHITE
```

```gdscript
# building_def.gd
class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0, 100000) var inventory_capacity: int = 0
```

```gdscript
# definition_catalog.gd
class_name DefinitionCatalog
extends Resource

@export var resources: Array[ResourceDef] = []
@export var buildings: Array[BuildingDef] = []

func validate() -> Array[StringName]:
    var errors: Array[StringName] = []
    var resource_ids: Dictionary = {}
    for definition in resources:
        if definition == null or definition.id.is_empty():
            errors.append(&"invalid_resource")
        elif resource_ids.has(definition.id):
            errors.append(&"duplicate_resource_id")
        else:
            resource_ids[definition.id] = true
    var building_ids: Dictionary = {}
    for definition in buildings:
        if definition == null or definition.id.is_empty() or definition.footprint.is_empty():
            errors.append(&"invalid_building")
        elif building_ids.has(definition.id):
            errors.append(&"duplicate_building_id")
        else:
            building_ids[definition.id] = true
    return errors

func get_resource(id: StringName) -> ResourceDef:
    for definition in resources:
        if definition.id == id:
            return definition
    return null

func get_building(id: StringName) -> BuildingDef:
    for definition in buildings:
        if definition.id == id:
            return definition
    return null
```

- [ ] **Шаг 4: создать семь `.tres`, каталог и локализованные названия**

Ресурсы: `wood`, `iron`, `coal`, `water`. Здания: `transfer_depot` footprint `[0,0]`, `boiler` footprint `[0,0;1,0]`, `steam_hammer` footprint `[0,0;1,0;0,1]`. Добавить русские и английские ключи `resource.*.name` и `building.*.name`.

- [ ] **Шаг 5: импортировать, запустить все тесты, закоммитить**

```bash
./scripts/check_project.sh
git add src/simulation/definitions data localization tests
git commit -m "feat: добавить каталог ресурсов и зданий"
```

---

### Задача 2: сценарий и атомарная загрузка состояния

**Файлы:**
- Создать: `src/simulation/definitions/initial_building_def.gd`
- Создать: `src/simulation/definitions/scenario_def.gd`
- Создать: `src/simulation/model/building_state.gd`
- Создать: `src/simulation/model/simulation_state.gd`
- Создать: `src/simulation/loading/scenario_load_result.gd`
- Создать: `src/simulation/loading/scenario_loader.gd`
- Создать: `data/scenarios/foundation.tres`
- Создать: `tests/unit/test_scenario_loader.gd`

**Интерфейсы:**
- `ScenarioLoader.load_scenario(definition) -> ScenarioLoadResult`.
- Успех возвращает `SimulationState`; отказ возвращает коды и `state == null`.
- Offset-координаты сценария преобразуются в axial odd-q footprint.

- [ ] **Шаг 1: написать падающие тесты успешной и атомарно ошибочной загрузки**

```gdscript
extends TestCase

func run() -> Array[String]:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var result := ScenarioLoader.new().load_scenario(scenario)
    assert_true(result.is_success(), "подготовленный сценарий должен загружаться")
    assert_eq(result.state.map_state.cell_count(), 324, "сценарий должен создать карту 18×18")
    assert_eq(result.state.buildings.size(), 3, "сценарий должен создать три здания")
    assert_eq(result.state.tick, 0, "новая симуляция должна начинаться до первого тика")

    var invalid := ScenarioDef.new()
    invalid.width = 18
    invalid.height = 18
    invalid.seed = 1
    invalid.catalog = scenario.catalog
    invalid.initial_buildings = [InitialBuildingDef.new()]
    invalid.initial_buildings[0].definition_id = &"missing"
    var rejected := ScenarioLoader.new().load_scenario(invalid)
    assert_true(not rejected.is_success(), "неизвестное здание должно отклонять весь сценарий")
    assert_true(rejected.errors.has(&"unknown_building_definition"), "отказ должен иметь структурированный код")
    assert_eq(rejected.state, null, "ошибочная загрузка не должна возвращать частичное состояние")
    return finish()
```

- [ ] **Шаг 2: подтвердить RED, затем реализовать типы состояния и результата**

`BuildingState` хранит `id`, `definition_id`, неизменяемую координату и `priority`. `SimulationState` хранит `tick = 0`, `seed`, `map_state`, `catalog`, `buildings`, `occupied_cells`, `next_entity_id` и события последнего тика.

- [ ] **Шаг 3: реализовать `ScenarioLoader`**

Алгоритм: проверить definition/catalog/dimensions/seed; предварительно проверить все initial buildings и каждый footprint; собрать временные здания и occupancy; создать `SimulationState` только после отсутствия ошибок. Формула odd-q: `r = row - (column - (column & 1)) / 2`.

- [ ] **Шаг 4: создать `foundation.tres`**

Seed `240713`; здания: склад `(3,4)`, котёл `(8,7)`, паровой молот `(13,10)`, приоритеты `2`.

- [ ] **Шаг 5: GREEN и коммит**

```bash
./scripts/check_project.sh
git add src/simulation data/scenarios tests/unit/test_scenario_loader.gd
git commit -m "feat: добавить загрузку подготовленного сценария"
```

---

### Задача 3: команды и стабильная очередь

**Файлы:**
- Создать: `src/simulation/commands/command_result.gd`
- Создать: `src/simulation/commands/simulation_command.gd`
- Создать: `src/simulation/commands/command_queue.gd`
- Создать: `tests/unit/test_command_queue.gd`

**Интерфейсы:**
- `SimulationCommand.set_building_priority(target_tick, sequence, building_id, priority)`.
- `CommandQueue.enqueue(command, completed_tick) -> CommandResult`.
- `take_for_tick(tick) -> Array[SimulationCommand]` сортирует по sequence.

- [ ] **Шаг 1: написать падающий тест порядка и отказов**

```gdscript
extends TestCase

func run() -> Array[String]:
    var queue := CommandQueue.new()
    assert_true(queue.enqueue(SimulationCommand.set_building_priority(2, 20, 1, 4), 0).accepted, "будущая команда должна приниматься")
    assert_true(queue.enqueue(SimulationCommand.set_building_priority(2, 10, 1, 1), 0).accepted, "порядок добавления не должен влиять на sequence")
    var commands := queue.take_for_tick(2)
    assert_eq(commands[0].sequence, 10, "меньший sequence должен выполняться первым")
    assert_eq(commands[1].sequence, 20, "больший sequence должен выполняться вторым")
    assert_eq(queue.enqueue(SimulationCommand.set_building_priority(0, 30, 1, 2), 0).code, &"past_tick", "прошедший тик должен отклоняться")
    assert_true(queue.enqueue(SimulationCommand.set_building_priority(3, 7, 1, 2), 0).accepted, "первый sequence должен приниматься")
    assert_eq(queue.enqueue(SimulationCommand.set_building_priority(3, 7, 1, 3), 0).code, &"duplicate_sequence", "повтор sequence должен отклоняться")
    return finish()
```

- [ ] **Шаг 2: RED, минимальная реализация, GREEN**

Команда хранит только значения. Очередь индексирует уникальность ключом `target_tick:sequence`; извлечённые команды удаляются и сортируются через `sort_custom` по `sequence`.

- [ ] **Шаг 3: коммит**

```bash
git add src/simulation/commands tests/unit/test_command_queue.gd
git commit -m "feat: добавить очередь команд симуляции"
```

---

### Задача 4: применение команд, инварианты и канонический хэш

**Файлы:**
- Создать: `src/simulation/systems/command_system.gd`
- Создать: `src/simulation/systems/invariant_checker.gd`
- Создать: `src/simulation/determinism/state_hasher.gd`
- Создать: `tests/unit/test_command_system.gd`
- Создать: `tests/unit/test_state_hasher.gd`

**Интерфейсы:**
- `CommandSystem.apply(state, command) -> CommandResult`.
- `InvariantChecker.check(state) -> Array[StringName]`.
- `StateHasher.canonicalize(state) -> String`, `hash_state(state) -> String`.

- [ ] **Шаг 1: тест команды — допустимая меняет приоритет, ошибочная не меняет**

Загрузить foundation, применить priority `4` к зданию `1`, проверить accepted и изменение. Затем применить priority `9` и неизвестный building ID, проверить коды и неизменность.

- [ ] **Шаг 2: реализовать `CommandSystem` и `InvariantChecker`**

Поддерживать только `set_building_priority`. Проверять тип, существование здания и диапазон `0..4`. Инварианты проверяют tick, ID, next ID, определения, координаты, occupancy и priority.

- [ ] **Шаг 3: тест канонического SHA-256**

Два независимо загруженных состояния должны иметь одинаковую canonical string и 64-символьный hash. Изменение priority должно менять hash; порядок добавления элементов Dictionary не должен влиять.

- [ ] **Шаг 4: реализовать `StateHasher`**

Формат: `tick=<n>|seed=<n>|next=<n>|buildings=[id,definition,q,r,priority;...]`; здания сортируются по числовому ID. Хэшировать UTF-8 через `HashingContext.HASH_SHA256`.

- [ ] **Шаг 5: GREEN и коммит**

```bash
./scripts/check_project.sh
git add src/simulation/systems src/simulation/determinism tests/unit
git commit -m "feat: добавить команды и хэш состояния"
```

---

### Задача 5: раннер тиков и determinism gate

**Файлы:**
- Создать: `src/simulation/runner/simulation_runner.gd`
- Создать: `tests/scenarios/test_deterministic_replay.gd`

**Интерфейсы:**
- `SimulationRunner.new(state)`.
- `enqueue(command) -> CommandResult`.
- `step() -> String` возвращает hash завершённого тика.
- `run_ticks(count) -> Array[String]`.

- [ ] **Шаг 1: написать сценарный тест двух одинаковых replay**

Создать два состояния из foundation, поставить одинаковые команды на тики `1`, `2`, `4`, выполнить 5 тиков и сравнить массивы хэшей. Создать третий запуск с одним другим priority и проверить отличие итогового хэша.

- [ ] **Шаг 2: RED и реализация `SimulationRunner`**

`step`: очистить события; взять `tick + 1`; получить команды; применить и записать коды событий; проверить инварианты; завершить tick; вернуть hash. При нарушении инварианта вызвать `push_error` и assert в debug/test.

- [ ] **Шаг 3: проверить 10 Гц как конфигурацию**

Добавить `const DEFAULT_TICKS_PER_SECOND := 10` и тест значения. Не вводить real-time Node на этом этапе.

- [ ] **Шаг 4: GREEN и коммит**

```bash
./scripts/check_project.sh
git add src/simulation/runner tests/scenarios
git commit -m "feat: добавить детерминированный раннер тиков"
```

---

### Задача 6: итоговая проверка и документация этапа

**Файлы:**
- Изменить: `README.md`
- Создать: `docs/stages/02-fixed-tick-simulation.md`
- Изменить: `tests/integration/test_project_configuration.gd`

**Интерфейсы:**
- Русский документ описывает реализованные типы, трассу команд, gate и границы этапа.
- Конфигурационный тест содержит все новые ключи локализации.

- [ ] **Шаг 1: обновить русскую документацию**

Указать: этап 1 и 2 завершены; запуск проверки; структура `src/simulation`; 4 ресурса, 3 здания; отсутствие рабочих и производства; пример создания runner и выполнения команды.

- [ ] **Шаг 2: полный автоматический gate**

```bash
./scripts/check_project.sh
```

Ожидание: все наборы тестов проходят; smoke run без `SCRIPT ERROR`, `Parse Error` и отсутствующих ресурсов.

- [ ] **Шаг 3: проверить determinism дважды в отдельных процессах**

Повторно запустить весь test runner; оба запуска должны быть зелёными и сценарный тест должен сравнивать хэши по каждому тику.

- [ ] **Шаг 4: code review, исправления, финальный коммит**

```bash
git add README.md docs/stages tests/integration
git commit -m "docs: описать завершение этапа 2"
```

- [ ] **Шаг 5: завершить feature-ветку**

Использовать `superpowers:requesting-code-review`, затем `superpowers:finishing-a-development-branch`. Не включать системы этапа 3.
