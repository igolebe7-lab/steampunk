# Stage 6 Contextual Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить постоянную контекстную обратную связь, подсветку наведения и допустимости, явное подтверждение водопровода и топологически корректную отрисовку дорог и труб перед валидной серией плейтестов.

**Architecture:** Чистые объекты `ConnectionTopology` и `InteractionFeedbackController` вычисляют геометрию и состояние интерфейса без мутации симуляции. `InteractionOverlayView` и контекстная панель только отображают рассчитанный снимок, а `ToolController` хранит незавершённое пользовательское действие до явного успеха или отмены. Авторитетная проверка остаётся в `CommandSystem` и `PipeCommandSystem`.

**Tech Stack:** Godot 4.6.2, GDScript, встроенный детерминированный test runner, CSV-локализация RU/EN.

## Global Constraints

- Русский язык является основной локалью; каждый новый видимый ключ сразу получает английский перевод.
- Подсказки постоянно доступны, объясняют только управление и обратную связь, но не стратегию и порядок развития.
- `SimulationState`, правила команд, цены, рецепты, скорости и условие завершения не меняются.
- Новые представления пересчитываются по событию, а не покадрово и не на каждом fixed tick без изменения данных.
- Производительность проверяется без постоянной видеозаписи; целевой runtime остаётся 30 FPS.
- Сырые файлы `output/`, `tmp/` и локальные плейтест-отчёты не добавляются в Git.

---

### Task 1: Вычисление топологии дорог и труб

**Files:**
- Create: `src/presentation/world/connection_topology.gd`
- Modify: `src/presentation/world/hex_grid_view.gd`
- Modify: `src/presentation/world/utility_network_view.gd`
- Create: `tests/unit/test_connection_topology.gd`
- Modify: `tests/integration/test_hex_grid_view.gd`
- Modify: `tests/integration/test_stage5_world_view.gd`

**Interfaces:**
- Produces: `ConnectionTopology.road_mask(map_state: HexMapState, coord: HexCoord, preview: Dictionary = {}) -> int`.
- Produces: `ConnectionTopology.pipe_mask(state: SimulationState, coord: HexCoord, preview: Dictionary = {}) -> int`.
- Produces: `ConnectionTopology.has_direction(mask: int, direction: int) -> bool`.
- Produces: `HexGridView.set_road_preview(coords: Array[HexCoord]) -> void`.
- Produces: `UtilityNetworkView.set_pipe_preview(coords: Array[HexCoord]) -> void`.

- [ ] **Step 1: Write the failing topology tests**

Добавить тесты, в которых центральная дорога имеет соседей только в направлениях `0` и `3`, а труба соединяется с одним сегментом и совместимым водяным портом здания. Проверить точные маски `1 << 0 | 1 << 3` и отсутствие битов остальных направлений. Отдельно проверить, что preview-координата добавляет тот же бит, который появится после фактического строительства.

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://tests/run_tests.gd
```

Expected: FAIL because `ConnectionTopology` and preview methods do not exist.

- [ ] **Step 3: Implement the minimal topology helper**

Использовать порядок `HexCoord.DIRECTIONS`. Для дорог бит включается только при наличии соседней клетки уровня `LEVEL_PATH` или выше либо такой клетки в preview. Для трубы бит включается при соседнем сегменте/preview той же commodity либо при здании с совместимым `UtilityPortDef` воды. Не добавлять направление в `SimulationState`.

- [ ] **Step 4: Make both views consume the masks**

В `HexGridView` заменить заранее созданные шесть `road_segments` на массив только активных полурёбер из маски. Изолированная клетка рисует центральную площадку. В `UtilityNetworkView` рисовать от центра к каждому активному ребру, включая порт здания, и закрывать конец круглым маркером. Preview строить тем же helper с добавленными гипотетическими координатами.

- [ ] **Step 5: Run tests to verify GREEN**

Run the full test runner. Expected: all suites pass and the road integration assertion confirms that a single road no longer has six branches.

- [ ] **Step 6: Commit**

```bash
git add src/presentation/world/connection_topology.gd src/presentation/world/hex_grid_view.gd src/presentation/world/utility_network_view.gd tests/unit/test_connection_topology.gd tests/integration/test_hex_grid_view.gd tests/integration/test_stage5_world_view.gd
git commit -m "fix: отображать реальную топологию сетей"
```

### Task 2: Чистая модель контекстной обратной связи

**Files:**
- Create: `src/app/interaction_feedback_state.gd`
- Create: `src/app/interaction_feedback_controller.gd`
- Create: `tests/unit/test_interaction_feedback_controller.gd`
- Modify: `tests/integration/test_project_configuration.gd`

**Interfaces:**
- Consumes: `ConnectionTopology` preview semantics from Task 1.
- Produces: `InteractionFeedbackController.evaluate(state: SimulationState, tools: ToolController, hover_kind: StringName, hover_id: int, hover_coord: HexCoord, selected_kind: StringName, selected_id: int, selected_coord: HexCoord) -> InteractionFeedbackState`.
- Produces: fields `mode`, `hint_key`, `target_state`, `reason_code`, `hover_kind`, `hover_id`, `hover_coord`, `selected_kind`, `selected_id`, `selected_coord`, `highlight_coords`, `highlight_entity_ids`, `preview_coords`, `cost`, `can_confirm`, `can_cancel`.

- [ ] **Step 1: Write failing feedback tests**

Проверить по одному поведению на тест: нейтральное наведение не меняет selection; занятая клетка дороги получает `INVALID` и `cell_occupied`; допустимая клетка склада требует соседнюю дорогу; первый шаг связи выделяет здания-источники; второй шаг использует `LogisticsLinkSystem.is_compatible`; труба выделяет только клетки рядом с выходом воды, затем только непрерывные свободные продолжения; полный путь `Stage5TestFactory.full_pipe_path()` разрешает подтверждение и возвращает стоимость `2`.

- [ ] **Step 2: Run tests to verify RED**

Expected: FAIL because both feedback classes are missing.

- [ ] **Step 3: Implement `InteractionFeedbackState`**

Сделать `RefCounted` со стабильными константами `NEUTRAL`, `VALID`, `INVALID`. Все массивы координат копировать, чтобы представление не могло изменить состояние инструмента. Хранить локализационные ключи и машинные reason-коды, а не готовые строки.

- [ ] **Step 4: Implement `InteractionFeedbackController`**

Вычислять только предпросмотр. Геометрические причины проверять теми же полями модели, что command-системы. Для совместимости связи вызывать существующий публичный `LogisticsLinkSystem.is_compatible`; для трубы проверять utility ports и занятость. Не вызывать команду на живом `SimulationState` и не копировать игровое состояние ради preview.

- [ ] **Step 5: Run tests to verify GREEN**

Expected: all suites pass; тест дополнительно сравнивает `StateHasher.hash(state)` до и после 100 вызовов `evaluate()`.

- [ ] **Step 6: Commit**

```bash
git add src/app/interaction_feedback_state.gd src/app/interaction_feedback_controller.gd tests/unit/test_interaction_feedback_controller.gd tests/integration/test_project_configuration.gd
git commit -m "feat: вычислять контекстную обратную связь"
```

### Task 3: Явное подтверждение и сохранение маршрута трубы

**Files:**
- Modify: `src/app/tool_controller.gd`
- Modify: `src/app/main.gd`
- Modify: `tests/integration/test_stage4_world_views.gd`
- Modify: `tests/integration/test_stage6_playtest_integration.gd`

**Interfaces:**
- Produces: `ToolController.prepare_pipe_intent() -> Dictionary`, which never clears the route.
- Produces: `ToolController.resolve_pipe_result(accepted: bool) -> void`, which clears and returns to inspect only on success.
- Produces: `ToolController.cancel() -> void`, the sole explicit failure/cancel clearing path.

- [ ] **Step 1: Write the failing state-machine tests**

Построить путь из двух координат, вызвать `prepare_pipe_intent()`, затем `resolve_pipe_result(false)` и проверить, что режим и обе координаты сохранены. После `resolve_pipe_result(true)` проверить возврат в inspect и пустой путь. Отдельно проверить явный `cancel()`.

- [ ] **Step 2: Run tests to verify RED**

Expected: FAIL because current `finish_pipe()` clears route before command resolution.

- [ ] **Step 3: Implement the minimal transaction lifecycle**

Заменить неявное повторное нажатие кнопки на подготовку intent без мутации. В `main.gd` после результата HUD вызвать `resolve_pipe_result(result == &"accepted")`. При отказе обновить feedback и оставить путь. Запись плейтеста должна по-прежнему фиксировать intent и result один раз.

- [ ] **Step 4: Run tests to verify GREEN**

Expected: all suites pass; integration test confirms unchanged simulation hash before accepted command and preserved rejected intent payload.

- [ ] **Step 5: Commit**

```bash
git add src/app/tool_controller.gd src/app/main.gd tests/integration/test_stage4_world_views.gd tests/integration/test_stage6_playtest_integration.gd
git commit -m "fix: сохранять незавершённый маршрут трубы"
```

### Task 4: Наведение, выбор и world overlay

**Files:**
- Create: `src/presentation/world/interaction_overlay_view.gd`
- Modify: `src/presentation/world/hex_grid_view.gd`
- Modify: `src/app/selection_controller.gd`
- Modify: `src/app/main.gd`
- Modify: `scenes/main.tscn`
- Create: `tests/integration/test_interaction_overlay_view.gd`
- Modify: `tests/integration/test_hex_grid_view.gd`
- Modify: `tests/integration/test_stage4_world_views.gd`

**Interfaces:**
- Produces: signal `HexGridView.local_position_hovered(local_position: Vector2)` emitted only when the resolved hex changes.
- Produces: `SelectionController.peek_at_local_position(local_position: Vector2) -> Dictionary`, which returns `{kind, entity_id, coord}` without changing selection.
- Produces: `InteractionOverlayView.configure(state: SimulationState, layout: HexLayout) -> void` and `present(feedback: InteractionFeedbackState) -> void`.

- [ ] **Step 1: Write failing hover and overlay tests**

Проверить, что `peek_at_local_position()` возвращает тот же приоритет hit-test, что selection, но не меняет `selected_*`. Передать overlay снимки neutral/valid/invalid и проверить кэшированные visual counts, координаты preview и отсутствие перестройки при повторной передаче эквивалентного снимка.

- [ ] **Step 2: Run tests to verify RED**

Expected: FAIL because hover query and overlay do not exist.

- [ ] **Step 3: Implement event-driven hover**

`HexGridView` обрабатывает `InputEventMouseMotion`, но отправляет сигнал только при смене гекса. `SelectionController` выделяет общий resolver hit-test без записи состояния. Наведение над UI не должно менять world selection.

- [ ] **Step 4: Implement `InteractionOverlayView`**

Рисовать hover тонкой рамкой, selection двойной рамкой, valid сплошной бирюзовой рамкой с точкой, invalid красной рамкой с крестом, а preview полупрозрачными рёбрами из `ConnectionTopology`. Позиции зданий брать из `SimulationState` и `HexLayout`; не добавлять дочерний Node на каждый гекс.

- [ ] **Step 5: Wire overlay in `main.gd` and scene**

Добавить один `InteractionOverlayView` в `World` после существующих world views. Обновлять feedback на hover, click, mode change, command result и изменённую топологию. На simulation tick переиспользовать последний hover без покадрового hit-test.

- [ ] **Step 6: Run tests to verify GREEN**

Expected: all suites pass; duplicate feedback snapshot does not increase overlay rebuild counter.

- [ ] **Step 7: Commit**

```bash
git add src/presentation/world/interaction_overlay_view.gd src/presentation/world/hex_grid_view.gd src/app/selection_controller.gd src/app/main.gd scenes/main.tscn tests/integration/test_interaction_overlay_view.gd tests/integration/test_hex_grid_view.gd tests/integration/test_stage4_world_views.gd
git commit -m "feat: подсвечивать наведение и допустимые цели"
```

### Task 5: Контекстная панель, active states и локализация

**Files:**
- Create: `src/app/interaction_panel_controller.gd`
- Modify: `src/app/main.gd`
- Modify: `scenes/main.tscn`
- Modify: `localization/game.csv`
- Create: `tests/unit/test_interaction_panel_controller.gd`
- Modify: `tests/integration/test_stage5_ui.gd`
- Modify: `tests/integration/test_project_configuration.gd`

**Interfaces:**
- Produces: `InteractionPanelController.configure(title: Label, hint: Label, target: Label, confirm: Button, cancel: Button, tool_buttons: Dictionary) -> void`.
- Produces: `InteractionPanelController.present(feedback: InteractionFeedbackState) -> void`.
- Emits: `confirm_requested` and `cancel_requested`.

- [ ] **Step 1: Write failing panel tests**

Проверить, что `present()` показывает локализованный режим и hint, скрывает пустую target-строку, отображает reason для invalid, включает confirm только при `can_confirm`, выводит цену и удерживает соответствующую tool-кнопку в `button_pressed`. Проверить RU/EN ключи и именованные параметры.

- [ ] **Step 2: Run tests to verify RED**

Expected: FAIL because panel controller and localization keys are missing.

- [ ] **Step 3: Implement the panel and scene layout**

Добавить компактную панель между миром и `BottomBar`, не перекрывающую правый инспектор. Инструментальные кнопки сделать `toggle_mode = true`, но управлять группой из controller, а не позволять Godot самопроизвольно снять активный режим. Confirm и Cancel являются отдельными кнопками.

- [ ] **Step 4: Add complete RU/EN copy**

Добавить ключи для названий режимов, нейтральных hint, действий, причин preview, confirm/cancel и tooltip с клавишами `1`–`6`, `Esc`. Не включать советы по порядку строительства.

- [ ] **Step 5: Wire confirm/cancel and remove repeat-button submit**

Кнопка `Провести трубу` только включает режим. `Подтвердить` вызывает `prepare_pipe_intent()`. `Отмена` и `Esc` вызывают `cancel()`. Горячие клавиши остаются совместимыми.

- [ ] **Step 6: Run tests to verify GREEN**

Expected: all suites pass and project configuration test finds every RU/EN key without raw key fallback.

- [ ] **Step 7: Commit**

```bash
git add src/app/interaction_panel_controller.gd src/app/main.gd scenes/main.tscn localization/game.csv tests/unit/test_interaction_panel_controller.gd tests/integration/test_stage5_ui.gd tests/integration/test_project_configuration.gd
git commit -m "feat: добавить постоянные контекстные подсказки"
```

### Task 6: Интеграционная, визуальная и производительная приёмка

**Files:**
- Modify: `tests/integration/test_stage6_playtest_integration.gd`
- Modify: `docs/stages/06-playtest-and-art-pass.md`
- Create: `docs/playtests/PT-DIAG-001-summary.ru.md`

**Interfaces:**
- Consumes: all Tasks 1–5.
- Produces: зафиксированный SHA сборки-кандидата для новой неизменной серии плейтестов.

- [ ] **Step 1: Add the failing end-to-end interaction test**

В главной сцене проверить последовательность hover → pipe mode → valid start → complete route → confirm → accepted. Затем проверить смену топологии дороги, active state кнопки, cancel и неизменность `StateHasher` от одних hover/selection действий.

- [ ] **Step 2: Run tests to verify RED, then complete missing wiring**

Expected RED: at least one full-scene assertion fails before the final wiring. Implement only the missing integration behavior, then rerun to GREEN.

- [ ] **Step 3: Run the complete project gate**

Run:

```bash
./scripts/check_project.sh
```

Expected: import succeeds, all suites pass, smoke launch contains no parse/script/resource errors.

- [ ] **Step 4: Run recorder performance comparison**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --script res://scripts/profile_playtest_recorder.gd
```

Expected: recorder overhead remains below `1.03`; interaction components are not instantiated in the headless simulation profile.

- [ ] **Step 5: Perform one short visual check**

Запустить обычную сцену без recorder, проверить hover, selection, valid/invalid, road cap/straight/bend/junction, pipe port/cap/bend, confirm/cancel и RU layout. Ограничить проверку несколькими минутами, не записывать видео и закрыть Godot после проверки.

- [ ] **Step 6: Document the diagnostic result and stage position**

В русском документе отметить, что `PT-001` был диагностикой владельца проекта, не входит в `1/5`, выявил непонятное составное действие трубы и привёл к UX-проходу. В stage doc заменить статус на «UX-кандидат проверен; ожидается новая неизменная серия» только после успешного gate.

- [ ] **Step 7: Commit**

```bash
git add tests/integration/test_stage6_playtest_integration.gd docs/stages/06-playtest-and-art-pass.md docs/playtests/PT-DIAG-001-summary.ru.md
git commit -m "test: принять контекстный UX-проход"
```

- [ ] **Step 8: Review and integrate**

Проверить `git diff a4ba1fa...HEAD`, отсутствие `output/`, `tmp/` и пользовательских checkpoint-файлов в index. После успешной проверки слить ветку в `main`, повторить `scripts/check_project.sh` на merge SHA и отправить `main` в `origin`.
