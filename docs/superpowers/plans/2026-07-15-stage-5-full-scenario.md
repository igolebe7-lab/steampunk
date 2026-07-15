# Этап 5: полный индустриальный сценарий — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать детерминированный сценарий на четыре ресурса с производственными циклами, локальной парой котёл–молот, ручной и трубопроводной подачей воды, фазами и итоговым экраном.

**Architecture:** Неизменяемые рецепты и коммунальные порты загружаются из Godot Resources. Изменяемые `ProductionState`, `UtilityNetworkState` и `ScenarioProgressState` входят в `SimulationState`, обрабатываются отдельными системами после физической логистики и включаются в `StateHasher v5`. UI только отправляет типизированные команды и читает готовое состояние.

**Tech Stack:** Godot 4.6.2, статически типизированный GDScript, `.tres`-данные, встроенный headless test runner, CSV-локализация RU/EN.

## Global Constraints

- Исходный язык игры, спецификаций, планов и проверочных документов — русский.
- Все пользовательские строки имеют русское и английское значения в `localization/game.csv`.
- Симуляция работает с фиксированной частотой 10 тиков в секунду и не зависит от кадров.
- Источники доставляют только на склады; производственные потребители получают физические грузы со складов.
- Пар этапа 5 является локальным состоянием пары котёл–молот, а не грузом и не трубопроводной сетью.
- Трубы воды могут сосуществовать с дорогой и не меняют движение носильщиков.
- Команды, рецепты и переходы фаз атомарны и детерминированы.
- Godot Resources содержат только неизменяемые определения; изменяемое состояние находится в `SimulationState`.
- Каждая задача выполняется через RED → GREEN → полный regression → commit.

---

## Карта файлов и границы ответственности

- `src/simulation/definitions/recipe_def.gd` — авторское определение рецепта.
- `src/simulation/definitions/utility_port_def.gd` — входной или выходной коммунальный порт здания.
- `src/simulation/model/production_state.gd` — прогресс и причины производства одного здания.
- `src/simulation/model/utility_segment_state.gd` — один сегмент коммунальной сети.
- `src/simulation/model/utility_network_state.gd` — сегменты, связность и счётчики потока.
- `src/simulation/model/scenario_progress_state.gd` — фаза, цели и итоговые метрики.
- `src/simulation/commands/pipe_command.gd` — типизированное строительство и разбор труб.
- `src/simulation/systems/utility_network_system.gd` — связность и дискретная подача воды.
- `src/simulation/systems/production_system.gd` — атомарные производственные циклы и прогрев.
- `src/simulation/systems/scenario_system.gd` — монотонные переходы фаз и первый удар.
- `src/presentation/world/utility_network_view.gd` — отрисовка трубы и потока.
- `src/app/result_panel_controller.gd` — локализованная итоговая панель без изменения симуляции.

---

### Task 1: Определения рецептов и производственное состояние

**Files:**
- Create: `src/simulation/definitions/recipe_def.gd`
- Create: `src/simulation/definitions/utility_port_def.gd`
- Create: `src/simulation/model/production_state.gd`
- Modify: `src/simulation/definitions/building_def.gd`
- Modify: `src/simulation/definitions/definition_catalog.gd`
- Modify: `src/simulation/model/simulation_state.gd`
- Create: `tests/helpers/stage5_test_factory.gd`
- Test: `tests/unit/test_stage5_definitions.gd`

**Interfaces:**
- Produces: `RecipeDef.input_amount(resource_id) -> int`, `UtilityPortDef`, `ProductionState`, `DefinitionCatalog.get_recipe(id) -> RecipeDef`, расширяемый `Stage5TestFactory`.
- Consumes: существующие `ResourceDef`, `BuildingDef`, `SimulationState`.

- [ ] **Step 1: Write the failing test**

```gdscript
func _assert_recipe_and_ports_validate() -> void:
    var recipe := RecipeDef.new()
    recipe.id = &"boiler_heat_cycle"
    recipe.input_resource_ids = [&"coal", &"water"]
    recipe.input_amounts = [1, 2]
    recipe.duration_ticks = 120
    assert_eq(recipe.input_amount(&"water"), 2, "рецепт хранит расход воды")

    var catalog := DefinitionCatalog.new()
    catalog.resources = [_resource(&"coal"), _resource(&"water")]
    catalog.recipes = [recipe]
    assert_true(catalog.validate().is_empty(), "валидный рецепт принимается")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd`

Expected: FAIL because `RecipeDef` and the catalog recipe API do not exist.

- [ ] **Step 3: Write minimal implementation**

```gdscript
class_name RecipeDef
extends Resource

@export var id: StringName
@export var input_resource_ids: Array[StringName] = []
@export var input_amounts: Array[int] = []
@export_range(1, 100000) var duration_ticks: int = 1
@export var result_code: StringName
@export var display_name_key: StringName
@export var description_key: StringName

func input_amount(resource_id: StringName) -> int:
    var index := input_resource_ids.find(resource_id)
    return 0 if index < 0 else input_amounts[index]
```

Add `recipes`, recipe validation, `get_recipe()`, building utility ports, and `SimulationState.production_states`.

- [ ] **Step 4: Run tests and commit**

Run: `./scripts/check_project.sh`

Expected: all existing suites plus `test_stage5_definitions` pass.

Commit: `feat: добавить определения производства этапа 5`

---

### Task 2: Состояние коммунальной сети и трубопроводные команды

**Files:**
- Create: `src/simulation/model/utility_segment_state.gd`
- Create: `src/simulation/model/utility_network_state.gd`
- Create: `src/simulation/commands/pipe_command.gd`
- Create: `src/simulation/systems/pipe_command_system.gd`
- Modify: `src/simulation/model/simulation_state.gd`
- Modify: `src/simulation/systems/command_system.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`
- Test: `tests/unit/test_pipe_commands.gd`

**Interfaces:**
- Produces: `PipeCommand.build(target_tick, sequence, cells)`, `PipeCommand.remove(...)`, `PipeCommandSystem.apply(state, command) -> CommandResult`.
- Consumes: `HexCoord`, `BuildingState.free_capacity()`, главный склад и `commodity_id == &"water"`.

- [ ] **Step 1: Write failing atomic command tests**

```gdscript
func _assert_build_is_atomic() -> void:
    var state := Stage5TestFactory.pipe_state()
    var cells: Array[HexCoord] = [HexCoord.new(2, 2), HexCoord.new(3, 2), HexCoord.new(4, 2)]
    state.get_building(state.main_warehouse_id).inventories[&"iron"] = 0
    var before := StateHasher.new().hash_state(state)
    var result := PipeCommandSystem.new().apply(state, PipeCommand.build(1, 1, cells))
    assert_eq(result.code, &"insufficient_iron", "дорогой путь отклоняется")
    assert_true(state.utility_network.segments.is_empty(), "частичных сегментов нет")
    assert_eq(StateHasher.new().hash_state(state), before, "отказ полностью сохраняет состояние")
```

Add separate assertions for duplicate cells, discontinuity, occupied cell, valid build cost `ceil(count / 2)`, and all-or-nothing removal.

- [ ] **Step 2: Run RED**

Run the Godot test runner. Expected: `PipeCommand` missing.

- [ ] **Step 3: Implement command and validation**

```gdscript
class_name PipeCommand
extends SimulationCommand

const BUILD := &"build"
const REMOVE := &"remove"
var operation: StringName
var cells: Array[HexCoord]
```

Validate the complete ordered path before charging iron or changing segments. Store segments by `coord.key()` and increment `utility_network.topology_revision` exactly once per successful command.

- [ ] **Step 4: Run regression and commit**

Run: `./scripts/check_project.sh`

Commit: `feat: добавить атомарные команды водопровода`

---

### Task 3: Данные четырёх источников и промышленного сценария

**Files:**
- Create: `data/buildings/iron_source.tres`
- Create: `data/buildings/coal_source.tres`
- Create: `data/buildings/water_source.tres`
- Create: `data/buildings/pump_station.tres`
- Create: `data/recipes/industrial_site_construction.tres`
- Create: `data/recipes/boiler_heat_cycle.tres`
- Create: `data/recipes/first_hammer_strike.tres`
- Modify: `data/buildings/boiler.tres`
- Modify: `data/buildings/steam_hammer.tres`
- Modify: `data/catalog.tres`
- Modify: `data/scenarios/physical_logistics.tres`
- Modify: `src/simulation/definitions/scenario_def.gd`
- Modify: `src/simulation/loading/scenario_loader.gd`
- Test: `tests/unit/test_stage5_scenario_loader.gd`

**Interfaces:**
- Produces scenario keys `main_warehouse`, `wood_source`, `iron_source`, `coal_source`, `water_source`, `pump_station`, `boiler`, `steam_hammer` and linked `ProductionState` entries.
- Consumes definitions from Tasks 1–2.

- [ ] **Step 1: Write failing loader assertions**

```gdscript
func run() -> Array[String]:
    var definition := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var result := ScenarioLoader.new().load_scenario(definition)
    assert_true(result.is_success(), "сценарий этапа 5 загружается")
    assert_eq(_count_sources(result.state), 4, "загружены четыре разных источника")
    assert_true(_find_building(result.state, &"pump_station") != null, "насосная существует")
    assert_eq(result.state.production_states.size(), 3, "площадка, котёл и молот имеют состояние")
    return finish()
```

- [ ] **Step 2: Run RED**

Expected: missing resources and only two wood sources.

- [ ] **Step 3: Add exact authored data**

Use the 18×18 map and six workers. Place buildings without footprint overlap; give boiler capacity 9, hammer/site capacity 24, and source buffers sufficient for the scripted window. Load recipe ids and local boiler/hammer ids through scenario keys rather than hard-coded entity ids.

- [ ] **Step 4: Run import, tests, and commit**

Run: `./scripts/check_project.sh`

Commit: `feat: собрать четырёхресурсный сценарий этапа 5`

---

### Task 4: Производственный спрос со складов

**Files:**
- Modify: `src/simulation/systems/job_system.gd`
- Modify: `src/simulation/systems/logistics_link_system.gd`
- Modify: `src/simulation/definitions/logistics_port_def.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`
- Create: `tests/unit/test_production_demand.gd`

**Interfaces:**
- Produces: production input targets derived from phase and recipe, warehouse-to-consumer jobs only.
- Consumes: `ProductionState`, recipe input amounts, `BuildingState.incoming_reserved`.

- [ ] **Step 1: Write failing demand tests**

```gdscript
func _assert_boiler_requests_three_cycles_without_overbooking() -> void:
    var state := Stage5TestFactory.production_state()
    var boiler := Stage5TestFactory.boiler(state)
    boiler.inventories[&"water"] = 2
    boiler.incoming_reserved[&"water"] = 1
    JobSystem.new().run(state, 1)
    assert_eq(_requested(state, boiler.id, &"water"), 3, "цель 6 учитывает запас и резерв")
    assert_true(_all_jobs_start_at_storage(state), "источник не доставляет прямо в котёл")
```

- [ ] **Step 2: Run RED**

Expected: production role does not create demand.

- [ ] **Step 3: Implement target-stock demand**

For the construction phase target 12 wood and 8 iron. For the boiler target 3 coal and 6 water. For the hammer target 2 iron only after full heat. Reuse logistics links and reservation rules; do not add a direct source exception.

- [ ] **Step 4: Run regression and commit**

Commit: `feat: направить складские потоки в производство`

---

### Task 5: Производственные циклы и устойчивый прогрев

**Files:**
- Create: `src/simulation/systems/production_system.gd`
- Modify: `src/simulation/systems/logistics_pipeline.gd`
- Modify: `src/simulation/model/simulation_event.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`
- Test: `tests/unit/test_production_system.gd`

**Interfaces:**
- Produces: `ProductionSystem.run(state, target_tick)`, events `production_started`, `production_completed`, `boiler_cooled`, `hammer_struck`.
- Consumes: recipes, physical inventories, scenario phase.

- [ ] **Step 1: Write failing cycle tests**

```gdscript
func _assert_five_cycles_heat_and_shortage_cools() -> void:
    var state := Stage5TestFactory.hot_boiler_state()
    for tick in range(1, 601):
        ProductionSystem.new().run(state, tick)
    assert_eq(_boiler(state).heat_level, 5, "пять циклов дают полный прогрев")
    _empty_boiler(state)
    for tick in range(601, 801):
        ProductionSystem.new().run(state, tick)
    assert_eq(_boiler(state).heat_level, 4, "200 тиков простоя снимают уровень")
```

Also assert all inputs are consumed together at cycle start and incomplete input changes neither inventory nor progress.

- [ ] **Step 2: Run RED**

Expected: `ProductionSystem` missing.

- [ ] **Step 3: Implement exact state machine**

Use stable building-id order. Complete running cycles first, then attempt starts. Boiler heat is clamped to `0..5`; at heat 5 completed cycles reset cooling without increasing heat. Hammer starts only when heat is 5 and its 2 iron are present.

- [ ] **Step 4: Run regression and commit**

Commit: `feat: реализовать прогрев котла и цикл молота`

---

### Task 6: Связность трубы и подача воды

**Files:**
- Create: `src/simulation/systems/utility_network_system.gd`
- Modify: `src/simulation/systems/logistics_pipeline.gd`
- Modify: `src/simulation/model/telemetry_window.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`
- Test: `tests/unit/test_utility_network_system.gd`

**Interfaces:**
- Produces: `UtilityNetworkSystem.run(state, target_tick)`, canonical components, one water every 20 ticks, manual/pipe counters.
- Consumes: utility segments, pump/boiler ports, `BuildingState.free_capacity()`.

- [ ] **Step 1: Write failing flow tests**

```gdscript
func _assert_connected_pump_fills_without_overbooking() -> void:
    var state := Stage5TestFactory.connected_pipe_state()
    var boiler := Stage5TestFactory.boiler(state)
    boiler.incoming_reserved[&"water"] = boiler.inventory_capacity
    UtilityNetworkSystem.new().run(state, 20)
    assert_eq(boiler.get_amount(&"water"), 0, "резерв блокирует переполнение")
    boiler.incoming_reserved.clear()
    UtilityNetworkSystem.new().run(state, 40)
    assert_eq(boiler.get_amount(&"water"), 1, "насос подал единицу воды")
    assert_eq(state.utility_network.pipe_water_delivered, 1, "канал измерен")
```

Add tests for broken path, full buffer, branching, insertion-order independence, and no worker jobs.

- [ ] **Step 2: Run RED**

Expected: missing system and counters.

- [ ] **Step 3: Implement deterministic graph traversal**

Sort segment keys before breadth-first traversal. Derive component ids from the lexicographically smallest coordinate key. Pump only when its component contains a compatible boiler and `target_tick % 20 == 0`.

- [ ] **Step 4: Run regression and commit**

Commit: `feat: добавить дискретную подачу воды по трубе`

---

### Task 7: Фазы сценария и итоговые метрики

**Files:**
- Create: `src/simulation/model/scenario_progress_state.gd`
- Create: `src/simulation/systems/scenario_system.gd`
- Modify: `src/simulation/model/simulation_state.gd`
- Modify: `src/simulation/systems/logistics_pipeline.gd`
- Modify: `src/simulation/model/telemetry_window.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`
- Test: `tests/unit/test_scenario_system.gd`

**Interfaces:**
- Produces: phase codes `observation`, `site_preparation`, `boiler_supply`, `warming`, `first_strike`, `completed`; baseline/final metric snapshots.
- Consumes: production states and tick.

- [ ] **Step 1: Write failing monotonic transition tests**

```gdscript
func _assert_phase_sequence() -> void:
    var state := Stage5TestFactory.scenario_state()
    ScenarioSystem.new().run(state, 899)
    assert_eq(state.scenario_progress.phase, &"observation", "до 900 тиков наблюдение")
    ScenarioSystem.new().run(state, 900)
    assert_eq(state.scenario_progress.phase, &"site_preparation", "площадка активирована")
    _complete_site(state)
    ScenarioSystem.new().run(state, 901)
    assert_eq(state.scenario_progress.phase, &"boiler_supply", "котёл разблокирован")
```

Add a completed-first-strike assertion and verify phase never regresses after cooling.

- [ ] **Step 2: Run RED**

Expected: `ScenarioProgressState` missing.

- [ ] **Step 3: Implement phase state machine**

Capture baseline at transition out of observation and final metrics on the single `hammer_struck` event. Use phase entry tick for active play time; pause does not advance ticks.

- [ ] **Step 4: Run regression and commit**

Commit: `feat: добавить фазы полного сценария`

---

### Task 8: StateHasher v5 и инварианты четырёх ресурсов

**Files:**
- Modify: `src/simulation/determinism/state_hasher.gd`
- Modify: `src/simulation/systems/invariant_checker.gd`
- Test: `tests/unit/test_stage5_invariants.gd`
- Modify: `tests/unit/test_state_hasher.gd`
- Modify: `tests/helpers/stage5_test_factory.gd`

**Interfaces:**
- Produces: canonical v5 payload covering production, utilities and scenario.
- Consumes: all new state from Tasks 1–7.

- [ ] **Step 1: Write failing hash and invariant tests**

```gdscript
func _assert_pipe_and_heat_change_hash() -> void:
    var state := Stage5TestFactory.scenario_state()
    var before := StateHasher.new().hash_state(state)
    Stage5TestFactory.boiler_production(state).heat_level = 1
    assert_true(StateHasher.new().hash_state(state) != before, "прогрев входит в hash v5")

func _assert_invalid_segment_is_rejected() -> void:
    var state := Stage5TestFactory.scenario_state()
    state.utility_network.add_segment(HexCoord.new(999, 999), &"water")
    assert_has(InvariantChecker.new().check(state), &"utility_segment_out_of_bounds")
```

- [ ] **Step 2: Run RED**

Expected: new state does not affect hash and invariants.

- [ ] **Step 3: Implement canonical payload and checks**

Sort production ids, segment coordinate keys, component members and counter keys. Check recipe existence, heat `0..5`, phase codes, port compatibility, capacity with reservations, and resource equation `initial + generated = inventory + carried + consumed`.

- [ ] **Step 4: Run regression and commit**

Commit: `test: расширить детерминизм на производство и трубы`

---

### Task 9: Инструмент трубы, представление и инспекторы

**Files:**
- Modify: `src/app/tool_controller.gd`
- Modify: `src/app/hud_controller.gd`
- Modify: `src/app/selection_controller.gd`
- Modify: `src/app/inspector_controller.gd`
- Modify: `src/app/main.gd`
- Create: `src/presentation/world/utility_network_view.gd`
- Modify: `src/presentation/world/logistics_world_view.gd`
- Modify: `scenes/main.tscn`
- Test: `tests/integration/test_stage5_ui.gd`
- Test: `tests/integration/test_stage5_world_view.gd`

**Interfaces:**
- Produces: tool modes `pipe_build` and `pipe_remove`, `HUDController` pipe intents, selection kind `utility_segment`, cached utility view.
- Consumes: pipe commands and new state.

- [ ] **Step 1: Write failing scene/UI tests**

```gdscript
func _assert_pipe_tool_submits_command(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var hud: HUDController = instance.get_hud_controller()
    var code := hud.submit_intent({
        &"code": &"pipe_build",
        &"cells": [HexCoord.new(6, 6), HexCoord.new(7, 6)],
    })
    assert_eq(code, &"accepted", "HUD проводит трубу через runner")
    assert_eq(runner.state.utility_network.segments.size(), 2, "сегменты применены")
```

Assert scene nodes for the pipe button, utility layer toggle, phase/progress labels, inspector text, and result panel.

- [ ] **Step 2: Run RED**

Expected: missing scene nodes and intent code.

- [ ] **Step 3: Implement interaction and cached drawing**

Build the selected path from ordered hex clicks, preview cost before submission, and clear it on success/Escape. Draw water segments in a dedicated node; rebuild geometry only when `topology_revision` changes and animate flow markers without rebuilding lines.

- [ ] **Step 4: Run regression and commit**

Commit: `feat: подключить управление и визуализацию водопровода`

---

### Task 10: Локализация, итоговая панель и минимальные эффекты

**Files:**
- Create: `src/app/result_panel_controller.gd`
- Create: `src/presentation/world/industrial_effects_view.gd`
- Modify: `localization/game.csv`
- Modify: `scenes/main.tscn`
- Modify: `src/app/main.gd`
- Test: `tests/unit/test_localization.gd`
- Modify: `tests/integration/test_stage5_ui.gd`

**Interfaces:**
- Produces: result rendering from `ScenarioProgressState`, localized phase/reason/command keys, one-shot hammer visual event.
- Consumes: completion state and telemetry snapshots.

- [ ] **Step 1: Write failing localization and result tests**

```gdscript
func _assert_stage5_keys_translate() -> void:
    for key in [&"phase.observation", &"phase.warming", &"reason.no_coal", &"reason.no_water", &"ui.result.title", &"command.invalid_pipe_path"]:
        TranslationServer.set_locale("ru")
        assert_true(tr(key) != String(key), "русский перевод существует: %s" % key)
        TranslationServer.set_locale("en")
        assert_true(tr(key) != String(key), "английский перевод существует: %s" % key)
```

- [ ] **Step 2: Run RED**

Expected: raw localization keys.

- [ ] **Step 3: Add RU/EN copy and procedural effects**

Generate four short mono `AudioStreamWAV` signals in `IndustrialEffectsView`: metallic pipe placement, low pump pulse, steam noise burst and hammer impact. The PCM bytes are created deterministically in code and contain no external or copyrighted media. Result panel reads named values and allows continuing simulation.

- [ ] **Step 4: Reimport, test, and commit**

Run: `./scripts/check_project.sh`

Commit: `feat: завершить локализованный финал сценария`

---

### Task 11: Acceptance, replay и баланс воды

**Files:**
- Modify: `tests/helpers/stage5_test_factory.gd`
- Create: `tests/scenarios/test_stage5_manual_completion.gd`
- Create: `tests/scenarios/test_stage5_pipe_completion.gd`
- Create: `tests/scenarios/test_stage5_water_throughput.gd`
- Create: `tests/scenarios/test_stage5_replay_stress.gd`

**Interfaces:**
- Produces: reproducible scripted traces for manual and pipe paths and printed acceptance line.
- Consumes: complete simulation.

- [ ] **Step 1: Write scenario tests with exact outcomes**

```gdscript
func _assert_pipe_advantage() -> void:
    var manual := Stage5TestFactory.run_water_window(false, 600)
    var piped := Stage5TestFactory.run_water_window(true, 600)
    var ratio := float(piped) / float(maxi(manual, 1))
    print("STAGE5_WATER manual=%d pipe=%d ratio=%.2f" % [manual, piped, ratio])
    assert_true(ratio >= 3.0, "труба минимум втрое быстрее")
```

Manual and pipe completion tests assert `phase == completed`, one hammer strike, and resource conservation. Stress test runs two identical 10 000-tick traces with pipe build/remove/rebuild commands and compares every hash.

- [ ] **Step 2: Run RED and tune authored data only**

Expected before tuning: completion time or ratio assertion fails. Change `.tres` source intervals, positions and initial stocks; do not add hidden production bonuses.

- [ ] **Step 3: Run GREEN twice**

Run the full test runner twice. Expected identical acceptance numbers and all suites pass.

- [ ] **Step 4: Commit**

Commit: `test: подтвердить полный сценарий этапа 5`

---

### Task 12: Русская документация и финальный gate

**Files:**
- Create: `docs/stages/05-full-industrial-scenario.md`
- Modify: `README.md`
- Modify: `scripts/check_project.sh` only if the existing gate does not already surface the Stage 5 acceptance line.

**Interfaces:**
- Produces: проверяемое русское описание управления, правил, метрик и границ этапа.
- Consumes: фактические результаты Task 11.

- [ ] **Step 1: Document implemented behavior**

Include controls, phase flow, exact recipes, pipe rules, manual fallback, diagnostics, acceptance numbers, known boundaries, and the next Stage 6 scope. Do not document unimplemented behavior.

- [ ] **Step 2: Run plan self-audit and source checks**

Run:

```bash
rg -n 'T''BD|TO''DO|FIX''ME|implement later|заполнить позже' docs README.md src tests data
git diff --check
```

Expected: no placeholders in Stage 5 files and no whitespace errors.

- [ ] **Step 3: Run final gate**

Run: `./scripts/check_project.sh`

Expected:

- all suites pass;
- Stage 4 road acceptance remains at least +25%;
- Stage 5 pipe/manual water ratio is at least 3.0;
- both 10 000-tick replays match;
- headless main scene starts without script or resource errors.

- [ ] **Step 4: Run real Godot visual smoke**

Run the installed Godot 4.6.2 project, inspect all phases/tool panels/result panel, capture a screenshot, and stop the process cleanly.

- [ ] **Step 5: Review, commit, merge, push**

Request a read-only final code review. Fix every Critical or Important finding with a regression test. Commit documentation, merge the verified branch into `main`, rerun `./scripts/check_project.sh` on merged `main`, and push `origin/main`.

Commit: `docs: завершить этап 5 полного сценария`
