# Этап 3: физическая логистика древесины — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** реализовать детерминированный цикл, в котором шесть видимых носильщиков многократно переносят по одной единице древесины от двух источников к перевалочному складу.

**Architecture:** чистые `RefCounted`-модели расширяют `SimulationState`; `LogisticsPipeline` выполняет небольшие системы в фиксированном порядке внутри `SimulationRunner`. Godot Nodes остаются адаптерами: `SimulationController` планирует тики, а представления интерполируют только завершённые состояния.

**Tech Stack:** Godot 4.6.2, статически типизированный GDScript, `.tres`, собственный headless test runner, SHA-256 через `HashingContext`, Git.

## Global Constraints

- Пользовательские документы и строки — на русском; технические идентификаторы — на английском.
- Базовая локаль `ru`; каждая новая строка имеет русское и тестовое английское значение.
- Симуляция не использует `Node`, `_process()`, frame delta, системное время, локаль или порядок Dictionary.
- Ядро работает на 10 тиках в секунду; delta разрешён только адаптеру представления.
- Один рабочий переносит одну древесину и не входит в footprint здания.
- Этап не добавляет дороги, размещение зданий, четыре грузовых ресурса, производство или диагностику этапа 4.
- Каждая задача проходит RED → GREEN → полный gate → отдельный коммит.

---

### Task 1: определения и сценарий физической логистики

**Files:**
- Modify: `src/simulation/definitions/building_def.gd`
- Modify: `src/simulation/definitions/initial_building_def.gd`
- Modify: `src/simulation/definitions/scenario_def.gd`
- Modify: `src/simulation/definitions/definition_catalog.gd`
- Create: `src/simulation/definitions/initial_worker_def.gd`
- Create: `src/simulation/definitions/initial_delivery_flow_def.gd`
- Create: `data/buildings/wood_source.tres`
- Modify: `data/catalog.tres`
- Create: `data/scenarios/physical_logistics.tres`
- Modify: `localization/game.csv`
- Modify: `tests/integration/test_project_configuration.gd`
- Test: `tests/unit/test_logistics_definitions.gd`

**Interfaces:**
- Produces: `BuildingDef.is_source() -> bool`.
- Produces: `InitialBuildingDef.scenario_key: StringName`.
- Produces: `ScenarioDef.initial_workers`, `delivery_flows`, `worker_ticks_per_hex`, `load_ticks`, `unload_ticks`, `repath_after_ticks`.

- [ ] **Step 1: написать падающий тест данных**

```gdscript
extends TestCase

func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    assert_true(scenario != null, "логистический сценарий должен загружаться")
    if scenario == null:
        return finish()
    assert_eq(scenario.initial_buildings.size(), 3, "нужны два источника и склад")
    assert_eq(scenario.initial_workers.size(), 6, "нужны шесть носильщиков")
    assert_eq(scenario.delivery_flows.size(), 2, "нужны два потока к складу")
    assert_eq(scenario.worker_ticks_per_hex, 4, "гекс проходится за четыре тика")
    var source := scenario.catalog.get_building(&"wood_source")
    assert_true(source != null and source.is_source(), "wood_source должен быть источником")
    assert_eq(source.source_resource_id, &"wood", "источник создаёт древесину")
    assert_eq(source.source_interval_ticks, 10, "интервал источника равен десяти тикам")
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — отсутствуют новые определения и ресурс сценария.

- [ ] **Step 3: реализовать определения**

```gdscript
# initial_worker_def.gd
class_name InitialWorkerDef
extends Resource
@export var offset_coord: Vector2i

# initial_delivery_flow_def.gd
class_name InitialDeliveryFlowDef
extends Resource
@export var source_key: StringName
@export var destination_key: StringName
@export var resource_id: StringName
@export_range(0, 4) var priority: int = 2
```

В `BuildingDef` добавить `source_resource_id`, `source_interval_ticks`, `source_capacity` и:

```gdscript
func is_source() -> bool:
    return not source_resource_id.is_empty()
```

В `ScenarioDef` добавить типизированные массивы workers/flows и четыре положительных timing-поля со значениями `4`, `2`, `2`, `10`. Каталог отклоняет неизвестный source resource, неположительный интервал/ёмкость и ненулевые source-параметры обычного здания.

- [ ] **Step 4: создать данные**

Сценарий 18×18: depot `(9,8)`, источники `(3,4)` и `(15,4)`, workers `(7,8)`, `(8,9)`, `(10,9)`, `(11,8)`, `(8,6)`, `(10,6)`. Ключи `depot`, `source_west`, `source_east`; два потока `wood` priority `2`. `wood_source`: interval `10`, capacity `8`. Добавить `building.wood_source.name,Источник древесины,Wood Source`.

В существующем `test_definition_catalog.gd` изменить ожидаемое число building definitions с `3` на `4`, сохранив отдельные проверки определений этапа 2.

- [ ] **Step 5: GREEN и коммит**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`  
Run: `./scripts/check_project.sh`  
Expected: все тесты и smoke-run проходят.

```bash
git add src/simulation/definitions data localization tests
git commit -m "feat: добавить определения физической логистики"
```

---

### Task 2: модель и атомарная загрузка

**Files:**
- Modify: `src/simulation/model/building_state.gd`
- Modify: `src/simulation/model/simulation_state.gd`
- Create: `src/simulation/model/delivery_flow_state.gd`
- Create: `src/simulation/model/delivery_job.gd`
- Create: `src/simulation/model/worker_state.gd`
- Create: `src/simulation/model/simulation_event.gd`
- Modify: `src/simulation/loading/scenario_loader.gd`
- Test: `tests/unit/test_logistics_scenario_loader.gd`

**Interfaces:**
- Produces: inventory methods `get_amount`, `add_amount`, `reserve_*`, `release_*`, `free_capacity`.
- Produces: `SimulationState.get_worker(id)`, `get_job(id)` и словари логистики.

- [ ] **Step 1: написать падающий тест loader**

```gdscript
extends TestCase

func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var loaded := ScenarioLoader.new().load_scenario(scenario)
    assert_true(loaded.is_success(), "сценарий должен создавать состояние")
    if loaded.state == null:
        return finish()
    assert_eq(loaded.state.workers.size(), 6, "создаются шесть workers")
    assert_eq(loaded.state.delivery_flows.size(), 2, "разрешаются два flows")
    assert_eq(loaded.state.worker_occupancy.size(), 6, "стартовые клетки заняты")
    var invalid := scenario.duplicate(true) as ScenarioDef
    invalid.initial_workers[1].offset_coord = invalid.initial_workers[0].offset_coord
    var rejected := ScenarioLoader.new().load_scenario(invalid)
    assert_true(rejected.errors.has(&"worker_overlap"), "overlap должен отклоняться")
    assert_eq(rejected.state, null, "ошибка не возвращает частичное состояние")
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — логистические поля состояния отсутствуют.

- [ ] **Step 3: реализовать модель**

`DeliveryFlowState`: immutable id/source/destination/resource/priority. `DeliveryJob`: ID, source/destination/resource, priority, created tick, state, worker ID, wait reason. `WorkerState`: immutable ID/initial coord/capacity и mutable coord/previous/segment/route/job/cargo/action/wait. `SimulationEvent`: code/tick/entity/job/resource IDs.

`BuildingState.free_capacity()` суммирует inventory и incoming reservations. Все reserve/release методы проверяют количество и возвращают `bool`.

- [ ] **Step 4: расширить loader**

Сначала построить временный `scenario_key → entity_id`, затем проверить workers и flows. Worker не может быть вне карты, в building footprint или на клетке другого worker. Flow обязан разрешать оба ключа и resource ID. Создать `SimulationState` только после финального `InvariantChecker` без ошибок.

- [ ] **Step 5: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: все тесты проходят.

```bash
git add src/simulation/model src/simulation/loading tests/unit/test_logistics_scenario_loader.gd
git commit -m "feat: добавить модель рабочих и доставок"
```

---

### Task 3: детерминированный A*

**Files:**
- Create: `src/simulation/pathfinding/path_result.gd`
- Create: `src/simulation/pathfinding/pathfinder.gd`
- Test: `tests/unit/test_pathfinder.gd`

**Interfaces:**
- Produces: `find_path(state, start, goals, dynamic_blocked = {}) -> PathResult`.
- Produces: `interaction_cells(state, building_id) -> Array[HexCoord]`.

- [ ] **Step 1: написать падающий тест**

```gdscript
extends TestCase

func run() -> Array[String]:
    var state := ScenarioLoader.new().load_scenario(load("res://data/scenarios/physical_logistics.tres") as ScenarioDef).state
    var finder := Pathfinder.new()
    var goals := finder.interaction_cells(state, state.delivery_flows[0].source_id)
    var worker_ids: Array = state.workers.keys()
    worker_ids.sort()
    var start := state.get_worker(worker_ids[0]).coord
    var first := finder.find_path(state, start, goals)
    var second := finder.find_path(state, start, goals)
    assert_true(first.is_success(), "путь должен находиться")
    assert_eq(first.keys(), second.keys(), "путь должен быть детерминирован")
    for coord in first.path:
        assert_true(not state.occupied_cells.has(coord.key()), "путь не входит в footprint")
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — классы pathfinding отсутствуют.

- [ ] **Step 3: реализовать A***

Open set извлекает минимум по `f`, затем `g`, `q`, `r`; соседи идут в `HexCoord.DIRECTIONS`. Стоимость шага равна `movement_cost`; исключаются непроходимые клетки, building footprint и `dynamic_blocked`. `interaction_cells` собирает уникальных проходимых соседей footprint и сортирует по `q/r`. `PathResult.path` включает start/goal, `cost` — сумму шагов.

- [ ] **Step 4: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: все тесты проходят.

```bash
git add src/simulation/pathfinding tests/unit/test_pathfinder.gd
git commit -m "feat: добавить детерминированный поиск пути"
```

---

### Task 4: источники и атомарные заказы

**Files:**
- Create: `src/simulation/systems/source_system.gd`
- Create: `src/simulation/systems/job_system.gd`
- Test: `tests/unit/test_source_and_job_systems.gd`

**Interfaces:**
- `SourceSystem.run(state, target_tick) -> void`.
- `JobSystem.run(state, target_tick) -> void`.

- [ ] **Step 1: написать падающий тест**

```gdscript
extends TestCase

func run() -> Array[String]:
    var state := ScenarioLoader.new().load_scenario(load("res://data/scenarios/physical_logistics.tres") as ScenarioDef).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    assert_eq(state.generated_totals.get(&"wood", 0), 2, "два источника создают две единицы")
    JobSystem.new().run(state, 10)
    assert_eq(state.jobs.size(), 2, "создаются два задания")
    JobSystem.new().run(state, 10)
    assert_eq(state.jobs.size(), 2, "зарезервированный груз не дублируется")
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — системы отсутствуют.

- [ ] **Step 3: реализовать системы**

Source IDs и flows сортируются численно. Source timer создаёт одну древесину при достижении interval, не превышает capacity и увеличивает `generated_totals`. JobSystem для каждой свободной единицы/места создаёт job, сразу резервирует outgoing/incoming, увеличивает `next_job_id` и добавляет `job_created`. Повторный run не создаёт заказ на уже зарезервированный груз.

- [ ] **Step 4: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: все тесты проходят.

```bash
git add src/simulation/systems/source_system.gd src/simulation/systems/job_system.gd tests/unit/test_source_and_job_systems.gd
git commit -m "feat: добавить источники и заказы доставки"
```

---

### Task 5: назначение и маршруты

**Files:**
- Create: `src/simulation/systems/assignment_system.gd`
- Create: `src/simulation/systems/path_system.gd`
- Test: `tests/unit/test_assignment_and_path_systems.gd`

**Interfaces:**
- `AssignmentSystem.run(state, pathfinder, target_tick) -> void`.
- `PathSystem.run(state, pathfinder, target_tick) -> void`.

- [ ] **Step 1: написать падающий тест**

```gdscript
extends TestCase

func run() -> Array[String]:
    var state := ScenarioLoader.new().load_scenario(load("res://data/scenarios/physical_logistics.tres") as ScenarioDef).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    JobSystem.new().run(state, 10)
    var finder := Pathfinder.new()
    AssignmentSystem.new().run(state, finder, 10)
    PathSystem.new().run(state, finder, 10)
    var assigned := 0
    for worker in state.workers.values():
        if worker.job_id > 0:
            assigned += 1
            assert_true(not worker.route.is_empty(), "назначенный worker получает route")
            assert_eq(state.get_job(worker.job_id).worker_id, worker.id, "worker/job связь симметрична")
    assert_eq(assigned, 2, "два задания получают двух workers")
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — системы отсутствуют.

- [ ] **Step 3: реализовать назначение и path state**

Jobs сортируются `priority desc, created_tick asc, id asc`. Для каждого job выбирается idle worker с минимальной A* стоимостью к source interaction cells, затем меньший worker ID. Assignment записывает взаимные ID. PathSystem переводит `assigned → to_source`, `awaiting_destination_path → to_destination`; при no path worker/job получают `blocked/no_path`, а cell reservation освобождается.

- [ ] **Step 4: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: все тесты проходят.

```bash
git add src/simulation/systems/assignment_system.gd src/simulation/systems/path_system.gd tests/unit/test_assignment_and_path_systems.gd
git commit -m "feat: добавить назначение и маршруты рабочих"
```

---

### Task 6: движение и резервирование гексов

**Files:**
- Create: `src/simulation/systems/movement_system.gd`
- Test: `tests/unit/test_movement_system.gd`

**Interfaces:**
- `MovementSystem.run(state, pathfinder, target_tick) -> void`.

- [ ] **Step 1: написать падающий тест конфликта**

```gdscript
extends TestCase

func run() -> Array[String]:
    var state := LogisticsTestFactory.two_workers_same_target()
    MovementSystem.new().run(state, Pathfinder.new(), 1)
    assert_eq(state.cell_reservations.size(), 1, "клетка имеет одну reservation")
    assert_eq(state.cell_reservations.values()[0], 1, "при равном ожидании выигрывает меньший ID")
    assert_eq(state.get_worker(2).wait_reason, &"cell_reserved", "проигравший объясняет ожидание")
    return finish()
```

Создать `tests/helpers/logistics_test_factory.gd` с `class_name LogisticsTestFactory`: валидное маленькое состояние 5×5 с двумя workers, разными occupied cells, общей следующей клеткой, segment duration `4` и пустыми building obstacles. Имя файла не начинается с `test_`, поэтому runner не принимает helper за suite.

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — MovementSystem отсутствует.

- [ ] **Step 3: реализовать движение**

Сначала завершать начатые segments и атомарно переводить occupancy. Затем workers сортировать по `wait_ticks desc, id asc` и резервировать следующий route cell. Конфликт даёт `cell_occupied`/`cell_reserved`. Swap запрещён. Каждые `repath_after_ticks` вызывать Pathfinder с occupancy/reservations других workers в dynamic blocked; отсутствие обхода сохраняет job и явный `no_path`.

- [ ] **Step 4: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: все тесты проходят.

```bash
git add src/simulation/systems/movement_system.gd tests/helpers/logistics_test_factory.gd tests/unit/test_movement_system.gd
git commit -m "feat: добавить движение и резервирование гексов"
```

---

### Task 7: погрузка, разгрузка и pipeline

**Files:**
- Create: `src/simulation/systems/inventory_system.gd`
- Create: `src/simulation/systems/telemetry_system.gd`
- Create: `src/simulation/systems/logistics_pipeline.gd`
- Modify: `src/simulation/runner/simulation_runner.gd`
- Test: `tests/scenarios/test_wood_delivery_cycle.gd`

**Interfaces:**
- `InventorySystem.run(state, target_tick) -> void`.
- `TelemetrySystem.run(state) -> void`.
- `LogisticsPipeline.run(state, target_tick) -> void`.

- [ ] **Step 1: написать падающий сценарный тест**

```gdscript
extends TestCase

func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var runner := SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
    runner.run_ticks(600)
    assert_true(runner.state.delivered_totals.get(&"wood", 0) >= 12, "завершаются минимум 12 доставок")
    assert_eq(_wood_in_world(runner.state), runner.state.generated_totals.get(&"wood", 0), "древесина сохраняется")
    return finish()

func _wood_in_world(state: SimulationState) -> int:
    var total := 0
    for building in state.buildings.values():
        total += building.get_amount(&"wood")
    for worker in state.workers.values():
        total += 1 if worker.cargo_resource_id == &"wood" else 0
    return total
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — раннер не выполняет логистику.

- [ ] **Step 3: реализовать операции и pipeline**

InventorySystem завершает loading/unloading на точном operation tick. Loading атомарно уменьшает inventory/outgoing reservation и даёт cargo; unloading переносит cargo в destination, снимает incoming reservation, увеличивает delivered total, удаляет active job и освобождает worker.

Pipeline вызывает source → jobs → assignment → path → movement → inventory → telemetry. Для foundation без workers/flows это безопасный no-op. Runner вызывает pipeline между commands и invariants.

- [ ] **Step 4: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: минимум 12 доставок, весь gate зелёный.

```bash
git add src/simulation/systems src/simulation/runner tests/scenarios/test_wood_delivery_cycle.gd
git commit -m "feat: завершить цикл доставки древесины"
```

---

### Task 8: инварианты, StateHasher v3 и replay

**Files:**
- Modify: `src/simulation/systems/invariant_checker.gd`
- Modify: `src/simulation/determinism/state_hasher.gd`
- Test: `tests/unit/test_logistics_invariants.gd`
- Test: `tests/scenarios/test_logistics_replay.gd`

**Interfaces:**
- `InvariantChecker.check(state)` возвращает новые структурированные коды.
- `StateHasher.canonicalize(state)` начинается с `v=3|`.

- [ ] **Step 1: написать падающий тест инвариантов**

```gdscript
extends TestCase

func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var ids: Array = state.workers.keys()
    ids.sort()
    state.get_worker(ids[1]).coord = state.get_worker(ids[0]).coord
    assert_true(InvariantChecker.new().check(state).has(&"worker_overlap"), "overlap обнаруживается")
    var clean := ScenarioLoader.new().load_scenario(scenario).state
    clean.generated_totals[&"wood"] = 1
    assert_true(InvariantChecker.new().check(clean).has(&"resource_conservation"), "потеря груза обнаруживается")
    return finish()
```

- [ ] **Step 2: написать падающий replay-тест**

```gdscript
extends TestCase

func run() -> Array[String]:
    var first := _runner()
    var second := _runner()
    assert_eq(first.run_ticks(300), second.run_ticks(300), "replay совпадает после каждого тика")
    assert_true(StateHasher.new().canonicalize(first.state).begins_with("v=3|"), "формат должен быть v3")
    return finish()

func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
```

- [ ] **Step 3: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — новые инварианты и v3 отсутствуют.

- [ ] **Step 4: реализовать проверки и canonical v3**

Проверить все условия раздела 14 спецификации. Conservation сравнивает generated totals с inventories + worker cargo. В v3 сортировать worker/job/flow/building/resource/cell IDs и включить все поля, влияющие на будущий тик: inventories/reservations, route/progress/cargo/wait, jobs, flows, occupancy/reservations, source timers, counters и next IDs.

Обновить golden-трассу существующего `tests/scenarios/test_deterministic_replay.gd`: foundation также получает префикс `v=3`, но логистические системы для него остаются no-op.

- [ ] **Step 5: закрепить golden checkpoints**

Отдельным Godot-процессом вычислить SHA тиков `1`, `100`, `200`, `300`, записать четыре значения константой в replay-тест и повторить test runner новым процессом.

- [ ] **Step 6: GREEN и коммит**

Run: `./scripts/check_project.sh` дважды.  
Expected: оба независимых процесса зелёные.

```bash
git add src/simulation/systems/invariant_checker.gd src/simulation/determinism tests
git commit -m "test: доказать детерминизм физической логистики"
```

---

### Task 9: real-time адаптер и graybox-представление

**Files:**
- Create: `src/app/simulation_controller.gd`
- Create: `src/presentation/world/building_view.gd`
- Create: `src/presentation/world/worker_view.gd`
- Create: `src/presentation/world/logistics_world_view.gd`
- Modify: `src/app/main.gd`
- Modify: `scenes/main.tscn`
- Modify: `localization/game.csv`
- Modify: `tests/integration/test_main_scene.gd`
- Create: `tests/integration/test_logistics_world_view.gd`

**Interfaces:**
- `SimulationController.configure(runner)`, `advance_frame(delta)`, `get_interpolation_alpha()`.
- Signals: `tick_completed(state)`, `interpolation_changed(alpha)`.
- `LogisticsWorldView.configure(state, layout)`, `capture_tick(state)`, `set_interpolation(alpha)`.

- [ ] **Step 1: написать падающий integration test**

```gdscript
extends TestCase

func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    var world := instance.get_node("World/LogisticsWorldView") as LogisticsWorldView
    assert_eq(world.get_worker_view_count(), 6, "создаются шесть WorkerView")
    assert_eq(world.get_building_view_count(), 3, "создаются три BuildingView")
    var before := world.get_worker_visual_position(0)
    var controller := instance.get_node("SimulationController") as SimulationController
    controller.set_process(false)
    for _index in 80:
        controller.advance_frame(0.1)
    assert_true(before != world.get_worker_visual_position(0), "worker визуально движется")
    instance.free()
    return finish()
```

- [ ] **Step 2: подтвердить RED**

Run: `./scripts/check_project.sh`  
Expected: FAIL — новые Nodes отсутствуют.

- [ ] **Step 3: реализовать controller и views**

Controller использует `tick_duration = 0.1`, accumulator и максимум 8 catch-up ticks за frame; игровая логика delta не получает. World view создаёт children по отсортированным IDs, сохраняет previous/current pixel position на tick и делает `lerp` по alpha. BuildingView рисует source зелёным, depot латунным и переводит name key. WorkerView рисует круг, направление, зелёный cargo marker, янтарный wait и красный blocked outline.

- [ ] **Step 4: подключить main**

Main загружает `physical_logistics.tres`, создаёт runner, настраивает grid из `runner.state.map_state`, controller и world view. Сигналы tick/alpha обновляют view. При loader error вызывается `push_error`, частичная логистика не создаётся. Камера и выбор гекса сохраняются.

- [ ] **Step 5: GREEN и коммит**

Run: `./scripts/check_project.sh`  
Expected: 6 worker views, 3 building views, существующие integration/smoke tests зелёные.

```bash
git add src/app src/presentation scenes localization tests/integration
git commit -m "feat: показать физическую логистику на карте"
```

---

### Task 10: документация, review, merge и push

**Files:**
- Modify: `README.md`
- Create: `docs/stages/03-physical-logistics.md`
- Modify: `tests/integration/test_project_configuration.gd`

- [ ] **Step 1: обновить русскую документацию**

README фиксирует завершённые этапы 1–3 и следующий этап 4. Документ этапа описывает source → job → assignment → path → movement → inventory, graybox-параметры, состояния ожидания, replay-gate и отсутствие дорог/производства.

- [ ] **Step 2: выполнить полный gate дважды**

Run: `./scripts/check_project.sh`  
Run: `./scripts/check_project.sh`  
Expected: оба запуска без script/parse/resource/smoke errors.

- [ ] **Step 3: независимое read-only code review**

Проверить spec alignment, conservation, worker/job symmetry, occupancy/reservations, hash completeness, no-path recovery, Node/simulation boundary, локализацию и отсутствие механик этапов 4–5.

- [ ] **Step 4: исправить все Critical/Important**

Каждое исправление получает regression-тест. После изменений повторить gate и read-only review исправляющего диапазона.

- [ ] **Step 5: закоммитить документацию**

```bash
git add README.md docs/stages tests/integration
git commit -m "docs: описать завершение этапа 3"
```

- [ ] **Step 6: слить, проверить main и отправить**

```bash
git merge --no-ff codex/etap-3-physical-logistics -m "merge: завершить этап 3 физической логистики"
./scripts/check_project.sh
git push origin main
```

Expected: `main` чистый и совпадает с `origin/main`; временное worktree удаляется только после успешного push.
