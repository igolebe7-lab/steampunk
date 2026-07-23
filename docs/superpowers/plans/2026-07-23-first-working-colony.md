# Первая рабочая колония — план реализации

> **Для агентных исполнителей:** ОБЯЗАТЕЛЬНЫЙ ПОДНАВЫК: использовать `superpowers:executing-plans` для последовательного выполнения задач. Шаги отслеживаются флажками `- [ ]`.

**Цель:** заменить короткий автоматически завершающийся сценарий полноценной сохраняемой игрой эпох I–II на процедурной карте с экспедицией, домохозяйствами, физическим строительством, добычей, производством, логистикой и исследованиями.

**Архитектура:** существующее детерминированное ядро `SimulationState` и fixed-tick pipeline расширяется обратно совместимыми подсистемами. Нормативные CSV загружаются версионированным валидатором в существующий `DefinitionCatalog`; старые `.tres`-сценарии остаются регрессионными тестами до переключения главной сцены. UI читает снимок модели и отправляет только типизированные команды.

**Технологии:** Godot 4.6.2, GDScript, Godot Resource/CSV, собственный headless test runner, fixed-tick simulation, русская локализация с английским контрольным переводом.

## Глобальные ограничения

- Основной режим — одна непрерывная колония; новая сцена не имеет автоматического финального экрана.
- Первая карта — 64×64 гекса, три биома, чанки 16×16, детерминированная генерация по seed.
- Домохозяйствам нужны только жильё, еда и вода; счастье, медицина, дети, война и угрозы исключены.
- Добыча отправляет предметы только на склады; производство получает предметы только со складов и возвращает продукцию на склады.
- Исследовательские наборы являются физическими предметами; Хартия поселения открывается измеряемой устойчивостью.
- Строительство всегда проходит через чертёж, доставку материалов и труд строителей.
- Русский — исходный язык UI и документации; каждую пользовательскую строку добавлять с английским переводом.
- Сетевые среды не хранятся как обычный инвентарь.
- Работники могут проходить друг через друга, но не через здания и непроходимые клетки.
- Все новые значения баланса читаются из `design_data/*.csv`; стабильные ID не локализуются.
- Полная проверка выполняется `./scripts/check_project.sh`; в коротком цикле используются фильтрованные тесты.
- Каждый этап сохраняет совместимость старого сценария `full_industrial` до задачи 11.

---

## Карта файлов

### Расширяемые существующие файлы

- `src/simulation/definitions/resource_def.gd` — метаданные ресурса и хранение.
- `src/simulation/definitions/building_def.gd` — эпоха, стоимость, рабочие места, буферы и условия местности.
- `src/simulation/definitions/recipe_def.gd` — произвольные выходы, длительность в секундах и рабочие требования.
- `src/simulation/definitions/definition_catalog.gd` — технологии, строительные стоимости и полная валидация.
- `src/simulation/model/hex_cell_state.gd` — биом, открытие, залежь и плодородие.
- `src/simulation/model/simulation_state.gd` — стройки, домохозяйства, исследования и режим колонии.
- `src/simulation/systems/logistics_pipeline.gd` — порядок новых систем.
- `src/app/main.gd` и `scenes/main.tscn` — запуск колонии и новый HUD.
- `localization/game.csv` — все новые русские и английские строки.

### Новые модули

- `src/simulation/loading/design_catalog_loader.gd` — версионированная загрузка CSV.
- `src/simulation/loading/colony_bootstrap.gd` — стартовая экспедиция.
- `src/simulation/generation/colony_world_generator.gd` — процедурная карта.
- `src/simulation/generation/world_generation_config.gd` — размер, чанки, seed и биомы.
- `src/simulation/model/construction_site_state.gd` — состояние физической стройки.
- `src/simulation/model/household_state.gd` — укрупнённое домохозяйство.
- `src/simulation/model/research_state.gd` — исследование и Хартия.
- `src/simulation/model/colony_progress_state.gd` — непрерывная прогрессия без сценарного финала.
- `src/simulation/commands/place_blueprint_command.gd` — размещение стройплощадки.
- `src/simulation/commands/cancel_construction_command.gd` — отмена с возвратом материалов.
- `src/simulation/commands/assign_recipe_command.gd` — выбор рецепта здания.
- `src/simulation/commands/start_research_command.gd` — запуск технологии.
- `src/simulation/systems/exploration_system.gd` — открытие клеток землемером.
- `src/simulation/systems/construction_system.gd` — доставка и строительный труд.
- `src/simulation/systems/household_system.gd` — потребление и миграция.
- `src/simulation/systems/colony_production_system.gd` — добыча и многовыходные рецепты.
- `src/simulation/systems/research_system.gd` — наборы, инженерное время и технологии.
- `src/simulation/saving/colony_save_codec.gd` — версионированный Dictionary.
- `src/simulation/saving/colony_save_service.gd` — атомарная запись и загрузка.
- `src/app/colony_hud_controller.gd` — обзор запасов и устойчивости.
- `src/app/build_menu_controller.gd` — каталог строительства.
- `src/app/colony_inspector_controller.gd` — точные причины простоя.
- `src/presentation/world/biome_world_view.gd` — биомы, туман и залежи.
- `src/presentation/world/construction_view.gd` — чертежи и прогресс стройки.
- `src/presentation/world/pixel_asset_library.gd` — единая загрузка игровых спрайтов.

---

### Задача 1: Быстрый фильтрованный цикл тестирования

**Файлы:**

- Изменить: `tests/run_tests.gd`
- Создать: `scripts/run_test_file.sh`
- Создать: `tests/unit/test_filtered_test_runner.gd`
- Изменить: `README.md`

**Интерфейсы:**

- Принимает: аргумент Godot `--test-filter=<substring>`.
- Выдаёт: запуск только путей тестов, содержащих подстроку; без фильтра поведение не меняется.

- [ ] **Шаг 1: написать падающий тест разбора фильтра**

```gdscript
extends TestCase

func run() -> Array[String]:
    var runner := load("res://tests/run_tests.gd").new()
    assert_eq(
        runner.test_filter_from_args(["--test-filter=test_design_catalog"]),
        "test_design_catalog",
        "runner должен читать фильтр после разделителя аргументов"
    )
    return finish()
```

- [ ] **Шаг 2: убедиться в ожидаемом падении**

Команда:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . \
  --script res://tests/run_tests.gd -- --test-filter=test_filtered_test_runner
```

Ожидание: FAIL из-за отсутствия `test_filter_from_args`.

- [ ] **Шаг 3: реализовать фильтр и скрипт запуска**

В `tests/run_tests.gd` добавить:

```gdscript
func test_filter_from_args(args: PackedStringArray) -> String:
    for argument in args:
        if argument.begins_with("--test-filter="):
            return argument.trim_prefix("--test-filter=")
    return ""
```

В `_run_all()` отфильтровать `suites` до загрузки скриптов. `scripts/run_test_file.sh` принимает ровно один непустой фильтр и вызывает Godot с `-- --test-filter="$1"`.

- [ ] **Шаг 4: проверить целевой и полный режим**

```bash
./scripts/run_test_file.sh test_filtered_test_runner
./scripts/run_test_file.sh test_definition_catalog
```

Ожидание: оба запуска завершаются `TESTS PASSED`.

- [ ] **Шаг 5: зафиксировать**

```bash
git add tests/run_tests.gd tests/unit/test_filtered_test_runner.gd scripts/run_test_file.sh README.md
git commit -m "test: добавить фильтрованный запуск наборов"
```

---

### Задача 2: Версионированный каталог проектных данных

**Файлы:**

- Изменить: `src/simulation/definitions/resource_def.gd`
- Изменить: `src/simulation/definitions/building_def.gd`
- Изменить: `src/simulation/definitions/recipe_def.gd`
- Изменить: `src/simulation/definitions/definition_catalog.gd`
- Создать: `src/simulation/definitions/technology_def.gd`
- Создать: `src/simulation/definitions/construction_cost_def.gd`
- Создать: `src/simulation/loading/design_catalog_loader.gd`
- Создать: `tests/unit/test_design_catalog_loader.gd`

**Интерфейсы:**

- Выдаёт: `DesignCatalogLoader.load_from_directory("res://design_data") -> CatalogLoadResult`.
- `CatalogLoadResult.catalog: DefinitionCatalog`, `errors: Array[String]`, `schema_version: int`.
- Старые `.tres` продолжают проходить `DefinitionCatalog.validate()`.

- [ ] **Шаг 1: написать тест полной загрузки**

```gdscript
func test_loads_normative_catalog() -> void:
    var result := DesignCatalogLoader.new().load_from_directory("res://design_data")
    assert_eq(result.errors, [], "нормативный каталог должен загружаться")
    assert_eq(result.catalog.resources.size(), 76, "должны загрузиться все ресурсы")
    assert_eq(result.catalog.buildings.size(), 86, "должны загрузиться все здания")
    assert_eq(result.catalog.recipes.size(), 97, "должны загрузиться все рецепты")
    assert_eq(result.catalog.technologies.size(), 40, "должны загрузиться все технологии")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_design_catalog_loader
```

Ожидание: parse error из-за отсутствующих классов.

- [ ] **Шаг 3: реализовать строгий CSV-reader**

`DesignCatalogLoader` читает заголовки по имени, преобразует `int/float/bool`, отклоняет повторный ID, неизвестную ссылку, лишнее или отсутствующее поле. Колонки `name_ru` используются только для контроля; `display_name_key` строится как `resource.<id>.name`, `building.<id>.name`, `recipe.<id>.name`, `technology.<id>.name`.

- [ ] **Шаг 4: расширить определения обратно совместимыми полями**

```gdscript
# BuildingDef
@export_range(1, 7) var era: int = 1
@export var category: StringName
@export_range(0, 100) var workers_min: int = 0
@export_range(0, 100) var workers_max: int = 0
@export_range(0, 100) var logistics_slots: int = 0
@export_range(0, 20) var input_buffer_cycles: int = 0
@export_range(0, 20) var output_buffer_cycles: int = 0
@export var terrain_rule: StringName = &"buildable"
@export var construction_costs: Array[ConstructionCostDef] = []
```

`RecipeDef` получает `output_resource_ids`, `output_amounts`, `workers_required`, `network_requirement`; старый `result_code` сохраняется для регрессии.

- [ ] **Шаг 5: проверить каталог и старые тесты**

```bash
./scripts/run_test_file.sh test_design_catalog_loader
./scripts/run_test_file.sh test_definition_catalog
```

Ожидание: PASS; размеры 76/86/97/40.

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/definitions src/simulation/loading tests/unit/test_design_catalog_loader.gd
git commit -m "feat: загрузить версионированный каталог игры"
```

---

### Задача 3: Процедурный мир, биомы, залежи и туман

**Файлы:**

- Изменить: `src/simulation/model/hex_cell_state.gd`
- Изменить: `src/simulation/model/hex_map_state.gd`
- Создать: `src/simulation/generation/world_generation_config.gd`
- Создать: `src/simulation/generation/colony_world_generator.gd`
- Создать: `src/simulation/systems/exploration_system.gd`
- Создать: `tests/unit/test_colony_world_generator.gd`
- Создать: `tests/unit/test_exploration_system.gd`
- Создать: `tests/scenarios/test_world_generation_replay.gd`

**Интерфейсы:**

- `ColonyWorldGenerator.generate(config: WorldGenerationConfig) -> HexMapState`.
- `HexCellState` добавляет `biome_id`, `revealed`, `deposit_id`, `deposit_amount`, `fertility`.
- Один seed создаёт канонически одинаковую карту и стартовую безопасную область.

- [ ] **Шаг 1: написать тест детерминизма и обязательных ресурсов**

```gdscript
var config := WorldGenerationConfig.standard(64, 64, 41073)
var first := ColonyWorldGenerator.new().generate(config)
var second := ColonyWorldGenerator.new().generate(config)
assert_eq(first.canonical_snapshot(), second.canonical_snapshot(), "seed должен воспроизводиться")
assert_true(first.count_biomes() >= 3, "нужно минимум три биома")
assert_true(first.has_deposit_near_center(&"logs", 12), "лес должен быть доступен у старта")
assert_true(first.has_deposit_near_center(&"stone", 12), "камень должен быть доступен у старта")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_colony_world_generator
```

- [ ] **Шаг 3: реализовать генератор**

Использовать только `RandomNumberGenerator` с заданным seed. Биомы строить из низкочастотных `FastNoiseLite`, затем выполнить детерминированный проход гарантий: вода, лес, камень, плодородная земля, железо и уголь в заданных кольцах. Не создавать Node и текстуры в генераторе.

- [ ] **Шаг 4: реализовать открытие**

```gdscript
func reveal_radius(map_state: HexMapState, center: HexCoord, radius: int) -> int:
    var changed := 0
    for coord in map_state.coords_in_radius(center, radius):
        var cell := map_state.get_cell(coord)
        if cell != null and not cell.revealed:
            cell.revealed = true
            changed += 1
    return changed
```

- [ ] **Шаг 5: проверить unit и replay**

```bash
./scripts/run_test_file.sh test_colony_world_generator
./scripts/run_test_file.sh test_exploration_system
./scripts/run_test_file.sh test_world_generation_replay
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/generation src/simulation/model src/simulation/systems/exploration_system.gd tests
git commit -m "feat: создать процедурный мир колонии"
```

---

### Задача 4: Стартовая экспедиция и непрерывное состояние колонии

**Файлы:**

- Создать: `src/simulation/model/colony_progress_state.gd`
- Изменить: `src/simulation/model/simulation_state.gd`
- Создать: `src/simulation/loading/colony_bootstrap.gd`
- Создать: `tests/helpers/colony_test_factory.gd`
- Создать: `tests/unit/test_colony_bootstrap.gd`
- Создать: `tests/scenarios/test_colony_idle_replay.gd`

**Интерфейсы:**

- `ColonyBootstrap.create(seed: int, catalog: DefinitionCatalog) -> ScenarioLoadResult`.
- Старт создаёт семь утверждённых объектов, домохозяйства, работников и ограниченные запасы.
- `ColonyProgressState` не имеет состояния `COMPLETED`.

- [ ] **Шаг 1: написать тест стартового состава**

```gdscript
var result := ColonyTestFactory.bootstrap(41073)
assert_eq(result.errors, [], "экспедиция должна создаваться")
assert_eq(result.state.map_state.width, 64, "карта должна быть 64×64")
assert_eq(result.state.colony_progress.mode, &"expedition", "стартовый режим")
assert_true(ColonyTestFactory.has_building(result.state, &"expedition_hq"), "нужен центр")
assert_true(result.state.workers.size() >= 8, "экспедиция должна иметь рабочих")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_colony_bootstrap
```

- [ ] **Шаг 3: реализовать bootstrap**

Размещать стартовые здания детерминированным шаблоном вокруг центра, но перед размещением выбирать ближайший связный пригодный участок. Первые ресурсы хранить на `supply_depot`; не создавать бесконечных источников.

- [ ] **Шаг 4: добавить idle replay**

Два запуска на 3000 тиков без команд должны иметь одинаковый хэш, не переходить в финальную фазу и не создавать отрицательные запасы.

- [ ] **Шаг 5: проверить**

```bash
./scripts/run_test_file.sh test_colony_bootstrap
./scripts/run_test_file.sh test_colony_idle_replay
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/model src/simulation/loading/colony_bootstrap.gd tests
git commit -m "feat: основать стартовую экспедицию"
```

---

### Задача 5: Физическое строительство

**Файлы:**

- Создать: `src/simulation/model/construction_site_state.gd`
- Создать: `src/simulation/commands/place_blueprint_command.gd`
- Создать: `src/simulation/commands/cancel_construction_command.gd`
- Создать: `src/simulation/systems/construction_system.gd`
- Изменить: `src/simulation/systems/command_system.gd`
- Изменить: `src/simulation/systems/logistics_pipeline.gd`
- Изменить: `src/simulation/model/simulation_state.gd`
- Создать: `tests/unit/test_construction_commands.gd`
- Создать: `tests/unit/test_construction_system.gd`
- Создать: `tests/scenarios/test_physical_construction_replay.gd`

**Интерфейсы:**

- `PlaceBlueprintCommand.create(tick, sequence, building_id, anchor, rotation)`.
- Стройплощадка имеет `delivered`, `reserved`, `labor_done_s`, `paused`, `priority`.
- Только завершённая площадка становится `BuildingState`.

- [ ] **Шаг 1: написать тест запрета мгновенного здания**

```gdscript
var result := CommandSystem.new().apply(
    state,
    PlaceBlueprintCommand.create(1, 1, &"logging_post", target, 0)
)
assert_true(result.accepted, "допустимый чертёж принимается")
assert_eq(state.buildings.size(), before, "здание не должно появляться мгновенно")
assert_eq(state.construction_sites.size(), 1, "должна появиться стройплощадка")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_construction_commands
```

- [ ] **Шаг 3: реализовать команды и атомарную валидацию**

Проверять открытие клетки, footprint, рельеф, технологию, пересечение и наличие строительной зоны. Размещение не списывает материалы со склада; оно создаёт спрос.

- [ ] **Шаг 4: реализовать доставку, труд и отмену**

`ConstructionSystem` после логистической доставки увеличивает труд только при назначенном строителе и полном комплекте материалов. Отмена возвращает доставленное на ближайший совместимый склад заданиями; если пути нет, оставляет возвратный груз на площадке.

- [ ] **Шаг 5: проверить полный цикл**

```bash
./scripts/run_test_file.sh test_construction_commands
./scripts/run_test_file.sh test_construction_system
./scripts/run_test_file.sh test_physical_construction_replay
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/model src/simulation/commands src/simulation/systems tests
git commit -m "feat: реализовать физическое строительство"
```

---

### Задача 6: Добыча, поля и обобщённое производство

**Файлы:**

- Создать: `src/simulation/commands/assign_recipe_command.gd`
- Создать: `src/simulation/systems/colony_production_system.gd`
- Изменить: `src/simulation/model/production_state.gd`
- Изменить: `src/simulation/model/building_state.gd`
- Изменить: `src/simulation/systems/logistics_pipeline.gd`
- Создать: `tests/unit/test_colony_production_system.gd`
- Создать: `tests/unit/test_deposit_extraction.gd`
- Создать: `tests/scenarios/test_early_industry_chain.gd`

**Интерфейсы:**

- `AssignRecipeCommand.create(tick, sequence, building_id, recipe_id)`.
- Производство поддерживает несколько выходов и повторяемые циклы.
- Добыча уменьшает `deposit_amount`; лес восстанавливается отдельным редким тиком.

- [ ] **Шаг 1: написать тест цепочки леса**

```gdscript
var logs_before := state.map_state.total_deposit(&"logs")
ColonyTestFactory.run_recipe(state, logging_id, &"logging_post_logs", 1)
assert_eq(logging.get_amount(&"logs"), 1, "бревно попадает в локальный буфер")
assert_eq(state.map_state.total_deposit(&"logs"), logs_before - 1, "залежь уменьшается")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_deposit_extraction
```

- [ ] **Шаг 3: реализовать единый цикл**

Алгоритм: проверить работников → сеть → полный вход → место для всех выходов → атомарно списать вход → выполнить таймер → атомарно добавить выход. Для добычи входом считается подходящая клетка рабочей зоны.

- [ ] **Шаг 4: реализовать запасы в циклах**

Производственный спрос равен `recipe_input × input_buffer_cycles − фактический запас − входящие резервы`. Выходной буфер ограничивает новый цикл до освобождения места.

- [ ] **Шаг 5: проверить раннюю цепочку**

Сценарный тест строит путь `лес → брёвна → склад → лесопилка → доски → склад` и `поле → зерно → мельница → мука → кухня → рационы`.

```bash
./scripts/run_test_file.sh test_colony_production_system
./scripts/run_test_file.sh test_deposit_extraction
./scripts/run_test_file.sh test_early_industry_chain
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/commands src/simulation/model src/simulation/systems tests
git commit -m "feat: запустить добычу и производство колонии"
```

---

### Задача 7: Домохозяйства, жильё, вода и еда

**Файлы:**

- Создать: `src/simulation/model/household_state.gd`
- Создать: `src/simulation/systems/household_system.gd`
- Изменить: `src/simulation/model/simulation_state.gd`
- Изменить: `src/simulation/systems/logistics_pipeline.gd`
- Создать: `tests/unit/test_household_system.gd`
- Создать: `tests/scenarios/test_household_supply_recovery.gd`

**Интерфейсы:**

- Домохозяйство предоставляет двух физических работников и занимает жилищный слот.
- Потребляет `1 ration + 1 water` каждые 180 секунд.
- `supply_state` принимает `stable`, `warning`, `shortage`, `departure_risk`.

- [ ] **Шаг 1: написать тест короткого и длительного дефицита**

```gdscript
var household := HouseholdState.new(1, cottage_id)
HouseholdSystem.new().run_interval(state, household, false, false)
assert_eq(household.supply_state, &"warning", "первый пропуск только предупреждает")
for _index in 4:
    HouseholdSystem.new().run_interval(state, household, false, false)
assert_eq(household.productivity_factor, 0.75, "длительный дефицит снижает труд")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_household_system
```

- [ ] **Шаг 3: реализовать потребление и восстановление**

Снабжённый интервал уменьшает счётчик дефицита на два, ненасыщенный увеличивает на один. Производительность применяется к строительному и производственному труду, но не телепортирует и не удаляет работника.

- [ ] **Шаг 4: реализовать миграцию**

Раз в 300 секунд при свободном жилье и пяти устойчивых интервалах создаётся одно домохозяйство и два работника. При десяти тяжёлых интервалах уезжает одно домохозяйство без текущего критического задания.

- [ ] **Шаг 5: проверить восстановление**

```bash
./scripts/run_test_file.sh test_household_system
./scripts/run_test_file.sh test_household_supply_recovery
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/model src/simulation/systems tests
git commit -m "feat: добавить домохозяйства и базовое снабжение"
```

---

### Задача 8: Логистика зданий, квоты и ручная тележка

**Файлы:**

- Изменить: `src/simulation/systems/logistics_link_system.gd`
- Изменить: `src/simulation/systems/assignment_system.gd`
- Изменить: `src/simulation/model/logistics_link_state.gd`
- Изменить: `src/simulation/model/worker_state.gd`
- Создать: `src/simulation/model/transport_profile.gd`
- Создать: `tests/unit/test_colony_automatic_routes.gd`
- Создать: `tests/unit/test_flexible_worker_quotas.gd`
- Создать: `tests/scenarios/test_handcart_throughput.gd`

**Интерфейсы:**

- Автомаршрут выбирает ближайший совместимый склад/потребителя и видим в состоянии.
- Ручной маршрут липкий; запрет отгрузки хранится по ресурсу в здании.
- `TransportProfile` задаёт вместимость и допустимую сеть без нового вида агента.

- [ ] **Шаг 1: написать тест запрета прямой поставки**

```gdscript
assert_true(
    not LogisticsLinkSystem.new().is_compatible(state, logging_id, sawmill_id, &"logs"),
    "добыча не должна снабжать производство напрямую"
)
assert_true(
    LogisticsLinkSystem.new().is_compatible(state, logging_id, warehouse_id, &"logs"),
    "добыча должна снабжать склад"
)
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_colony_automatic_routes
```

- [ ] **Шаг 3: реализовать роли отправителей и назначения**

Для добычи допустим только склад; для склада — потребитель; для производства — склад. Автовыбор сортирует кандидатов по стоимости пути и ID. Квота является жёстким верхним пределом.

- [ ] **Шаг 4: реализовать профиль тачки**

Тачка переносит три единицы, требует работника и тропу/дорогу; на открытой земле медленнее носильщика. Профиль назначается работнику артелью, не создаёт столкновений с другими агентами.

- [ ] **Шаг 5: проверить гибкость и производительность**

```bash
./scripts/run_test_file.sh test_colony_automatic_routes
./scripts/run_test_file.sh test_flexible_worker_quotas
./scripts/run_test_file.sh test_handcart_throughput
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/model src/simulation/systems tests
git commit -m "feat: связать потоки колонии и добавить тачки"
```

---

### Задача 9: Хартия, исследования и технологии эпох I–II

**Файлы:**

- Создать: `src/simulation/model/research_state.gd`
- Создать: `src/simulation/commands/start_research_command.gd`
- Создать: `src/simulation/systems/research_system.gd`
- Изменить: `src/simulation/model/colony_progress_state.gd`
- Изменить: `src/simulation/systems/logistics_pipeline.gd`
- Создать: `tests/unit/test_research_system.gd`
- Создать: `tests/unit/test_settlement_charter.gd`
- Создать: `tests/scenarios/test_era_two_progression.gd`

**Интерфейсы:**

- `StartResearchCommand.create(tick, sequence, technology_id)`.
- Наборы резервируются в лаборатории, атомарно списываются при запуске, инженерное время накапливается физическими работниками.
- Хартия проверяет возможности, а не список конкретных зданий.

- [ ] **Шаг 1: написать тест Хартии**

```gdscript
assert_true(not ResearchSystem.new().charter_ready(state), "стартовые припасы не равны устойчивости")
ColonyTestFactory.configure_sustainable_supply(state)
assert_true(ResearchSystem.new().charter_ready(state), "местные еда вода жильё дерево и камень дают Хартию")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_settlement_charter
```

- [ ] **Шаг 3: реализовать измеряемую устойчивость**

Условия: локальное положительное производство рационов и воды, пять минут расчётного запаса, местные брёвна и камень, один свободный жилищный слот, открытая пригодная область поселения.

- [ ] **Шаг 4: реализовать исследования**

Проверять prerequisite, наборы, инженера, лабораторию и прототип. Завершение добавляет ID в `unlocked_technologies`, но не показывает финальный экран.

- [ ] **Шаг 5: проверить прогрессию**

```bash
./scripts/run_test_file.sh test_research_system
./scripts/run_test_file.sh test_settlement_charter
./scripts/run_test_file.sh test_era_two_progression
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/model src/simulation/commands src/simulation/systems tests
git commit -m "feat: открыть Хартию и исследования колонии"
```

---

### Задача 10: Версионированные сохранения

**Файлы:**

- Создать: `src/simulation/saving/colony_save_codec.gd`
- Создать: `src/simulation/saving/colony_save_service.gd`
- Изменить: `src/simulation/determinism/state_hasher.gd`
- Создать: `tests/unit/test_colony_save_codec.gd`
- Создать: `tests/scenarios/test_save_load_replay.gd`

**Интерфейсы:**

- `ColonySaveCodec.encode(state) -> Dictionary`.
- `ColonySaveCodec.decode(payload, catalog) -> ScenarioLoadResult`.
- `ColonySaveService.save_atomic(slot_id, state) -> StringName`.
- Текущая схема: `schema_version = 1`.

- [ ] **Шаг 1: написать round-trip тест**

```gdscript
var encoded := ColonySaveCodec.new().encode(state)
var decoded := ColonySaveCodec.new().decode(encoded, state.catalog)
assert_eq(decoded.errors, [], "сохранение должно загружаться")
assert_eq(
    StateHasher.new().hash_state(decoded.state),
    StateHasher.new().hash_state(state),
    "round-trip должен сохранять состояние"
)
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_colony_save_codec
```

- [ ] **Шаг 3: реализовать канонический codec**

Сериализовать только данные модели: seed, tick, карта, здания, стройки, работники, задания, связи, домохозяйства, исследования и сети. Не сериализовать Node, Resource-ссылки и UI.

- [ ] **Шаг 4: реализовать атомарный service**

Писать во временный файл `slot.tmp`, проверять декодирование, затем переименовывать в `slot.json`. Ошибка не повреждает предыдущий файл.

- [ ] **Шаг 5: проверить продолжение replay**

```bash
./scripts/run_test_file.sh test_colony_save_codec
./scripts/run_test_file.sh test_save_load_replay
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add src/simulation/saving src/simulation/determinism tests
git commit -m "feat: сохранять и продолжать колонию"
```

---

### Задача 11: Полноразмерный интерфейс рабочей колонии

**Файлы:**

- Изменить: `scenes/main.tscn`
- Изменить: `src/app/main.gd`
- Создать: `src/app/colony_hud_controller.gd`
- Создать: `src/app/build_menu_controller.gd`
- Создать: `src/app/colony_inspector_controller.gd`
- Создать: `src/presentation/world/biome_world_view.gd`
- Создать: `src/presentation/world/construction_view.gd`
- Изменить: `localization/game.csv`
- Создать: `tests/integration/test_colony_main_scene.gd`
- Создать: `tests/integration/test_colony_build_flow.gd`
- Создать: `tests/unit/test_colony_localization.gd`

**Интерфейсы:**

- Центральная карта, верхний обзор, левое строительство и правый контекстный инспектор.
- Режимы: осмотр, строительство, дорога, связь, отмена; подсказки не перекрывают карту.
- Первый запуск загружает новую колонию или последний слот; тест может передать фиксированный seed.

- [ ] **Шаг 1: написать интеграционный тест новой сцены**

```gdscript
assert_true(instance.has_node("UI/SafeArea/Shell/Body/BuildPanel"), "нужен каталог строительства")
assert_true(instance.has_node("UI/SafeArea/Shell/Body/InspectorPanel"), "нужен инспектор")
assert_true(instance.has_node("World/BiomeWorldView"), "нужен вид биомов")
assert_true(not instance.has_node("UI/ResultPanel"), "колония не должна иметь сценарный финал")
```

- [ ] **Шаг 2: проверить падение**

```bash
./scripts/run_test_file.sh test_colony_main_scene
```

- [ ] **Шаг 3: перестроить сцену**

Сохранить камеру, zoom 0.5–2.0, 1920×1080 и адаптацию 1280×720. Кнопки строительства формируются из открытых `BuildingDef`. Предпросмотр показывает footprint, соединения, стоимость, материалы и точную ошибку.

- [ ] **Шаг 4: реализовать инспектор и ресурсы**

Инспектор здания показывает работников, рецепт, входы, выходы, циклы запаса, связи и причину остановки. Склад показывает строки ресурсов с входящими/исходящими резервами. Верхняя панель показывает избранное и открывает полный складской обзор.

- [ ] **Шаг 5: добавить ru/en и проверить**

```bash
./scripts/run_test_file.sh test_colony_localization
./scripts/run_test_file.sh test_colony_main_scene
./scripts/run_test_file.sh test_colony_build_flow
```

- [ ] **Шаг 6: зафиксировать**

```bash
git add scenes src/app src/presentation localization tests
git commit -m "feat: развернуть интерфейс рабочей колонии"
```

---

### Задача 12: Пиксель-арт, производительность и приёмочная версия

**Файлы:**

- Создать: `art/styleframes/colony-era-1-approved.png`
- Создать: `art/sprites/terrain/*.png`
- Создать: `art/sprites/buildings/*.png`
- Создать: `art/sprites/workers/*.png`
- Создать: `src/presentation/world/pixel_asset_library.gd`
- Изменить: `src/presentation/world/hex_grid_view.gd`
- Изменить: `src/presentation/world/building_view.gd`
- Изменить: `src/presentation/world/worker_view.gd`
- Создать: `tests/integration/test_pixel_asset_coverage.gd`
- Создать: `tests/scenarios/test_first_working_version_acceptance.gd`
- Создать: `docs/stages/07-first-working-colony.md`
- Изменить: `README.md`

**Интерфейсы:**

- Ассеты используют одну утверждённую псевдоизометрическую проекцию, палитру и размер тайла.
- Все обязательные здания эпох I–II имеют отдельный читаемый спрайт; заглушка допускается только для закрытого позднего контента.
- Acceptance выполняет реальный игровой путь без прямой правки состояния.

- [ ] **Шаг 1: утвердить технический styleframe внутри документа**

Зафиксировать размер тайла, точку опоры, направления света, масштаб работника, палитру и границы спрайтов. Сгенерировать/дорисовать один целостный вид стартовой колонии и использовать его как источник отдельных ассетов.

- [ ] **Шаг 2: написать тест покрытия**

```gdscript
for definition in catalog.buildings:
    if definition.era <= 2:
        assert_true(
            ResourceLoader.exists(PixelAssetLibrary.path_for_building(definition.id)),
            "обязательному зданию нужен спрайт: %s" % definition.id
        )
```

- [ ] **Шаг 3: подключить пакетную отрисовку**

Кэшировать текстуры и геометрию чанков; не создавать новый Sprite2D на каждый кадр. Скрытые чанки и агенты вне камеры обновлять реже. Туман и подсветки рисовать отдельными лёгкими слоями.

- [ ] **Шаг 4: написать приёмочный сценарий**

Сценарий должен командами:

1. исследовать стартовый район;
2. обеспечить воду и еду;
3. построить лесозаготовку, карьер и склад;
4. доставить материалы на две стройки;
5. запустить доски, каменные блоки, инструменты и рационы;
6. принять Хартию;
7. произвести и потратить исследовательский набор;
8. сохранить игру, загрузить и продолжить ещё 600 тиков.

- [ ] **Шаг 5: выполнить полную проверку и профиль**

```bash
./scripts/check_project.sh
```

Ожидание: все тесты и smoke-run проходят. Затем выполнить 20-минутный технический прогон карты 64×64; целевые значения — 30 FPS, отсутствие роста памяти и средний симуляционный тик не более 50% бюджета кадра.

- [ ] **Шаг 6: документировать результат**

`docs/stages/07-first-working-colony.md` содержит реализованные системы, измеренные значения, известные ограничения и следующий игровой шлюз. README описывает управление и запуск новой колонии.

- [ ] **Шаг 7: зафиксировать и отправить**

```bash
git add art src scenes tests docs README.md localization
git commit -m "feat: выпустить первую рабочую колонию"
git push origin main
```

---

## Самопроверка плана

- Все обязательные пункты раздела 22 мастер-GDD имеют задачу: карта и туман — 3; экспедиция — 4; строительство — 5; добыча и цепочки — 6; население — 7; склады, носильщики, дороги и тачки — 8; технологии — 9; сохранение — 10; UI — 11; визуал и приёмка — 12.
- Пар, железная дорога, автоматоны и эпохи III–VII остаются в каталоге, но не входят в первую рабочую реализацию.
- Старый промышленный сценарий не удаляется до подтверждения новой сцены и остаётся регрессионным тестом.
- Фильтрованный тестовый цикл решает проблему длительной разработки и перегрева без ослабления финальной проверки.
- Стабильные ID и сигнатуры между задачами согласованы; новых обязательных внешних зависимостей нет.
- Пустых маркеров и неопределённых шагов нет.
