# План реализации этапа 4: управление и диагностика

> **Для Codex:** выполнять последовательно по TDD: RED → GREEN → REFACTOR. После каждого блока запускать весь headless-набор, потому что он выполняется быстро и ловит ошибки регистрации `class_name`.

**Цель:** реализовать дороги, один размещаемый перевалочный склад, визуальные логистические связи, квоты и безопасные приоритеты, диагностические слои, инспекторы, метрики и полный русско-английский интерфейс.

**Архитектура:** детерминированная симуляция остаётся единственным источником истины. `Resource` хранит неизменяемый баланс, `RefCounted` — состояние и системы, `Node` — только ввод и представление. Команды применяются атомарно через `SimulationRunner`; интерфейс не меняет состояние напрямую.

**Стек:** Godot 4.6.2, GDScript, встроенный headless-раннер проекта.

**Спецификация:** `docs/superpowers/specs/2026-07-15-stage-4-management-diagnostics-design.md`

## Общие ограничения

- Русский — базовый язык, английский каталог должен оставаться полным.
- Пользовательский текст не зашивается в GDScript или сцены.
- Этап 4 использует только древесину; производства и ресурсы этапа 5 не добавляются.
- Открытая земля, тропа, грунтовая дорога проходят за 4, 3, 2 тика.
- Тропа стоит 1 древесину, улучшение до дороги — ещё 2.
- Перевалочный склад стоит 10, вмещает 40, имеет 2 исходящих места; разбор возвращает 5.
- Главный склад вмещает 100 и оплачивает строительство.
- Источник первого уровня имеет 2 исходящих рабочих места.
- Высокий приоритет не превышает квоту, лимит отправителя и не создаёт постоянного голодания.
- Команды на паузе меняют ревизию, но не игровой тик.
- Формат хэша состояния повышается до версии 4.
- Никакой потери или телепортации груза.

## Стандартная команда проверки

```bash
./scripts/check_project.sh
```

## Задача 1. Расширить определения и состояние этапа 4

**Файлы:**

- создать `src/simulation/definitions/road_level_def.gd`
- создать `src/simulation/definitions/logistics_port_def.gd`
- создать `src/simulation/model/logistics_link_state.gd`
- изменить `src/simulation/definitions/building_def.gd`
- изменить `src/simulation/definitions/definition_catalog.gd`
- изменить `src/simulation/model/hex_cell_state.gd`
- изменить `src/simulation/model/building_state.gd`
- изменить `src/simulation/model/worker_state.gd`
- изменить `src/simulation/model/delivery_job.gd`
- изменить `src/simulation/model/simulation_state.gd`
- изменить `src/simulation/determinism/state_hasher.gd`
- создать `tests/unit/test_stage4_state_model.gd`
- изменить `tests/unit/test_state_hasher.gd`

### RED

Добавить тесты, которые требуют:

- уровни дороги `0/1/2` и длительности `4/3/2`;
- уровни, роли, рабочие места и политику прямой поставки здания;
- стабильный `LogisticsLinkState`;
- поля связи у работника и заказа;
- ревизию состояния;
- канонизацию `v=4`, чувствительную к дороге, связи и ревизии.

Запустить стандартную проверку и убедиться, что тест падает из-за отсутствующих типов или полей.

### GREEN

Реализовать минимальную модель. Не добавлять системы поведения. Обновить `StateHasher` с устойчивой сортировкой.

### REFACTOR

Убрать дублирующиеся константы уровней и ролей в определения. Повторно запустить стандартную проверку.

## Задача 2. Добавить типизированные команды и атомарные дороги

**Файлы:**

- переработать `src/simulation/commands/simulation_command.gd` в базовый тип
- создать `src/simulation/commands/build_road_command.gd`
- создать `src/simulation/commands/depot_command.gd`
- создать `src/simulation/commands/link_command.gd`
- создать `src/simulation/commands/link_settings_command.gd`
- создать `src/simulation/commands/dispatch_policy_command.gd`
- изменить `src/simulation/commands/command_queue.gd`
- изменить `src/simulation/systems/command_system.gd`
- создать `tests/unit/test_road_commands.gd`
- изменить `tests/unit/test_command_queue.gd`
- изменить `tests/unit/test_command_system.gd`

### RED

Проверить:

- участок земли улучшается `0 → 1 → 2`;
- цены равны 1 и 2 за клетку;
- стоимость списывается из главного склада;
- занятая, отсутствующая или максимальная клетка отклоняет весь пакет;
- при нехватке древесины состояние не меняется;
- идентификатор, порядок и снимок подкласса команды стабильны.

Наблюдать ожидаемое падение.

### GREEN

Реализовать полную предварительную проверку пакета и только затем мутацию. Результат команды возвращает код и структурированные параметры без пользовательского текста.

### REFACTOR

Выделить общую проверку здания-плательщика и стоимость уровня. Запустить полный набор.

## Задача 3. Реализовать размещение и разбор перевалочного склада

**Файлы:**

- создать `data/buildings/main_warehouse.tres`
- изменить `data/buildings/transfer_depot.tres`
- изменить `data/catalog.tres`
- изменить `data/scenarios/physical_logistics.tres`
- изменить `src/simulation/loading/scenario_loader.gd`
- изменить `src/simulation/systems/command_system.gd`
- изменить `src/simulation/systems/invariant_checker.gd`
- создать `tests/unit/test_depot_commands.gd`
- изменить `tests/unit/test_logistics_definitions.gd`
- изменить `tests/unit/test_logistics_invariants.gd`

### RED

Тестами потребовать:

- начальный центральный объект — `main_warehouse`;
- размещение одного `transfer_depot` за 10 древесины;
- свободную клетку рядом с дорогой;
- отказ при втором складе;
- вместимость 40 и 2 места;
- разбор только пустого склада без jobs и reservations;
- возврат 5 древесины и освобождение клетки.

### GREEN

Добавить роли складов, создание стабильного entity id, изменение `occupied_cells`, проверки и события.

### REFACTOR

Собрать проверку footprint и соседней дороги в чистые функции. Запустить полный набор.

## Задача 4. Реализовать логистический граф и автоматический выбор

**Файлы:**

- создать `src/simulation/systems/logistics_link_system.gd`
- изменить `src/simulation/loading/scenario_loader.gd`
- изменить `src/simulation/systems/command_system.gd`
- изменить `src/simulation/systems/logistics_pipeline.gd`
- изменить `src/simulation/systems/invariant_checker.gd`
- создать `tests/unit/test_logistics_links.gd`
- создать `tests/unit/test_automatic_destination.gd`

### RED

Проверить:

- источники связываются только со складами;
- перевалочный склад связывается с главным;
- запрещённая прямая поставка исключает главный склад;
- автоматический выбор использует стоимость пути и стабильное равенство;
- автоматическая связь закрепляется;
- ручная связь заменяет автоматическую;
- дубликат и запрещённый цикл отклоняются;
- остановленная отгрузка не создаёт новых jobs;
- удаление линии переводит активный груз в состояние завершения рейса.

### GREEN

Создать словарь связей и `next_link_id`, портовую совместимость и dirty-флаг топологии. Автовыбор выполнять только при отсутствии валидного назначения или по явной команде.

### REFACTOR

Сохранить старые `delivery_flows` только как формат начальных данных; после загрузки симуляция работает через `LogisticsLinkState`. Запустить полный набор.

## Задача 5. Реализовать квоты и справедливое распределение носильщиков

**Файлы:**

- создать `src/simulation/systems/workforce_system.gd`
- изменить `src/simulation/systems/job_system.gd`
- изменить `src/simulation/systems/assignment_system.gd`
- изменить `src/simulation/systems/inventory_system.gd`
- изменить `src/simulation/systems/logistics_pipeline.gd`
- изменить `src/simulation/systems/invariant_checker.gd`
- создать `tests/unit/test_workforce_system.gd`
- создать `tests/scenarios/test_transfer_depot_flow.gd`
- изменить `tests/scenarios/test_logistics_replay.gd`

### RED

Потребовать:

- сумма квот не превышает места отправителя;
- линия не получает больше своей квоты;
- два источника первого уровня не забирают более двух workers каждый;
- приоритет влияет на дефицит, но aging обслуживает ожидающую линию;
- валидные назначения сохраняются;
- заблокированное место освобождается после завершения рейса;
- ресурс проходит `источник → перевалочный → главный` без потерь.

### GREEN

Распределять доступные места детерминированно по фактической квоте, весу приоритета, возрасту ожидания и стабильному id. Не переназначать носильщика с грузом.

### REFACTOR

Убрать прежнюю зависимость job priority от BuildingState. Запустить полный набор и длительный прогон.

## Задача 6. Добавить оконную телеметрию и объяснение узких мест

**Файлы:**

- создать `src/simulation/model/telemetry_window.gd`
- создать `src/simulation/model/diagnostic_report.gd`
- изменить `src/simulation/systems/telemetry_system.gd`
- создать `src/simulation/systems/diagnostics_system.gd`
- изменить `src/simulation/systems/movement_system.gd`
- изменить `src/simulation/systems/inventory_system.gd`
- изменить `src/simulation/systems/logistics_pipeline.gd`
- создать `tests/unit/test_telemetry_window.gd`
- создать `tests/unit/test_diagnostics_system.gd`

### RED

Проверить окно 600 тиков и прогрев 100 тиков, throughput в единицах/мин, latency, движение/ожидание, очередь, загрузку links и клеток. Потребовать структурированные причины `no_destination`, `destination_full`, `source_full`, `worker_shortage`, `route_conflict`, `relay_backlog`, `no_path`.

### GREEN

Использовать ограниченное кольцевое окно и накопительные счётчики. Диагностика выбирает наибольшую измеренную потерю и не изменяет симуляцию.

### REFACTOR

Не создавать пользовательские строки в системах. Запустить полный набор.

## Задача 7. Реализовать паузу, скорости и команды без продвижения времени

**Файлы:**

- изменить `src/simulation/runner/simulation_runner.gd`
- изменить `src/app/simulation_controller.gd`
- изменить `src/simulation/determinism/state_hasher.gd`
- создать `tests/unit/test_paused_commands.gd`
- создать `tests/unit/test_simulation_speed.gd`
- изменить `tests/scenarios/test_deterministic_replay.gd`

### RED

Потребовать:

- `flush_commands()` применяет команды, увеличивает revision и не меняет tick;
- pause прекращает обычные тики;
- ×1, ×2, ×4 дают соответствующее число фиксированных тиков;
- смена скорости не изменяет логику одного тика;
- повтор команд на паузе даёт одинаковый `v=4` hash.

### GREEN

Разделить игровую скорость и длительность фиксированного тика. На паузе интерфейс вызывает только транзакцию команд.

### REFACTOR

Оставить единственный путь применения команд через runner. Запустить полный набор.

## Задача 8. Реализовать представление дорог, связей и динамических зданий

**Файлы:**

- изменить `src/presentation/world/hex_grid_view.gd`
- изменить `src/presentation/world/logistics_world_view.gd`
- изменить `src/presentation/world/building_view.gd`
- изменить `src/presentation/world/worker_view.gd`
- создать `src/presentation/world/diagnostics_view.gd`
- создать `src/app/selection_controller.gd`
- создать `src/app/tool_controller.gd`
- создать `tests/integration/test_stage4_world_views.gd`
- изменить `tests/integration/test_logistics_world_view.gd`

### RED

Тестами потребовать:

- разные визуальные уровни дороги;
- добавление и удаление BuildingView после команд;
- выбор работника, здания, связи и гекса в нужном порядке;
- состояния инструментов и отмену;
- линии auto/manual и переключаемые слои;
- визуальное состояние blocked/waiting/normal.

### GREEN

Рисовать кэшированную геометрию через `_draw()`, обновлять после снимка, а не каждый кадр. Интерполяцию оставить только носильщикам.

### REFACTOR

Разделить выбор, инструменты и рисование. Не вводить event bus или autoload. Запустить полный набор.

## Задача 9. Собрать HUD, инспекторы и локализацию

**Файлы:**

- создать `src/app/hud_controller.gd`
- создать `src/app/inspector_controller.gd`
- изменить `src/app/main.gd`
- изменить `scenes/main.tscn`
- изменить `localization/game.csv`
- изменить `tests/unit/test_localization.gd`
- изменить `tests/integration/test_main_scene.gd`
- создать `tests/integration/test_stage4_ui.gd`

### RED

Потребовать:

- верхнюю панель древесины, throughput и времени;
- левую панель трёх слоёв;
- правые инспекторы worker/building/link;
- нижние четыре инструмента;
- локализованные коды ошибок и причин ожидания;
- отсутствие жёстко заданного пользовательского текста;
- полный набор ключей RU/EN;
- компоновку без перекрытия при 1280×720.

### GREEN

Собрать UI из контейнеров, обеспечить прокрутку инспектора и горячие клавиши. `HUDController` создаёт команды, но не меняет состояние.

### REFACTOR

Вынести форматирование чисел и причин в локализованные функции интерфейса. Запустить полный набор.

## Задача 10. Сбалансировать сценарий, доказать критерий и обновить документацию

**Файлы:**

- изменить `data/scenarios/physical_logistics.tres`
- создать `tests/scenarios/test_road_throughput_improvement.gd`
- создать `tests/scenarios/test_stage4_replay_and_stress.gd`
- создать `docs/stages/04-management-and-diagnostics.md`
- изменить `README.md`

### RED

Зафиксировать baseline-сценарий одинаковой длины и улучшенную копию с тем же seed. Тест должен сначала показать отсутствие требуемого роста.

### GREEN

Настроить карту, начальные связи и дорожный коридор так, чтобы разумное улучшение дороги давало не менее 25% throughput без скрытого бонуса складу. Проверить 10 000 тиков с изменениями связей и отсутствие потерь.

### REFACTOR

Описать на русском:

- что реализовано;
- как управлять;
- как читать метрики;
- известные границы этапа;
- что входит в этап 5.

Запустить:

```bash
git diff --check
./scripts/check_project.sh
```

Затем выполнить GUI-запуск установленным Godot, визуально проверить 1280×720, кириллицу, дороги, связи, слои и инспекторы. После независимого ревью исправить Critical и Important замечания, повторить полный gate, объединить с `main` и отправить в `origin`.
