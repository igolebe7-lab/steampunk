# Stage 6 Fullsize Responsive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить сжатый абсолютный HUD 1280×720 полноразмерным адаптивным интерфейсом 1920×1080, в котором подсказка, инструменты и инспектор не перекрываются, а камера центрирует карту в свободной мировой области.

**Architecture:** Главная сцена получает полноэкранный контейнерный каркас `TopBar + Body`, где `Body` состоит из левой панели, расширяемого центра и правого инспектора. Чистый `ResponsiveLayoutController` читает геометрию `WorldSpace` только при resize и передаёт безопасный экранный прямоугольник в `CameraController`; игровые системы и `SimulationState` не меняются.

**Tech Stack:** Godot 4.6.2, GDScript, `Control`/`Container`, `Camera2D`, встроенный детерминированный test runner, RU/EN-локализация.

## Global Constraints

- Проектное полотно: `1920×1080`; начальный режим окна: `DisplayServer.WINDOW_MODE_MAXIMIZED` (`2`).
- Минимально поддерживаемый физический размер окна: `1280×720`.
- Stretch mode: `canvas_items`; stretch aspect: `expand`.
- На `1920×1080` центральная мировая область не меньше `1100×720 px`.
- Контекстная панель, инструменты и инспектор никогда не пересекаются.
- Русская локаль остаётся основной; игровые тексты и механика не меняются.
- `SimulationState`, recorder и хеш симуляции не зависят от layout.
- `PT-V01` остаётся локальной технически недействительной диагностикой; новая серия начинается с `PT-R01` на новом неизменном SHA.
- Layout пересчитывается только при конфигурации и resize, не в `_process()`.

---

### Task 1: Конфигурация полноразмерного окна

**Files:**
- Modify: `project.godot:19-26`
- Modify: `tests/integration/test_project_configuration.gd:24-40`

**Interfaces:**
- Produces: project settings `viewport_width = 1920`, `viewport_height = 1080`, overrides `1600×900`, `mode = 2`, stretch aspect `expand`.

- [ ] **Step 1: Write failing project-settings assertions**

```gdscript
assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920, "проектная ширина должна быть 1920")
assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080, "проектная высота должна быть 1080")
assert_eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1600, "оконный override должен быть 1600")
assert_eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 900, "оконный override должен быть 900")
assert_eq(ProjectSettings.get_setting("display/window/size/mode"), 2, "игра должна запускаться развёрнутой")
assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "HUD масштабируется как canvas items")
assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "экран расширяет полезную область")
```

- [ ] **Step 2: Run the targeted suite to verify RED**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/fullsize-config-red.log --path "$PWD" --script /private/tmp/run_godot_suite.gd -- res://tests/integration/test_project_configuration.gd
```

Expected: FAIL for old `1280×720` and missing new settings.

- [ ] **Step 3: Set the project window values**

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1600
window/size/window_height_override=900
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 4: Run the targeted suite to verify GREEN**

Expected: `SUITE PASSED: res://tests/integration/test_project_configuration.gd`.

- [ ] **Step 5: Commit**

```bash
git add project.godot tests/integration/test_project_configuration.gd
git commit -m "feat: настроить полноразмерное окно"
```

### Task 2: Безопасная область камеры

**Files:**
- Create: `src/app/responsive_layout_controller.gd`
- Modify: `src/presentation/world/camera_controller.gd`
- Create: `tests/unit/test_responsive_layout_controller.gd`
- Modify: `tests/unit/test_camera_controller.gd`

**Interfaces:**
- Produces: `ResponsiveLayoutController.configure(world_space: Control, camera: CameraController) -> void`.
- Produces: `ResponsiveLayoutController.refresh(viewport_size: Vector2, fit_world: bool = false) -> bool`.
- Produces: `ResponsiveLayoutController.snapshot() -> Dictionary` with `world_rect`, `viewport_size`, `revision`.
- Produces: `CameraController.configure_safe_view(screen_rect: Rect2, viewport_size: Vector2, fit_world: bool = false) -> void`.
- Produces: `CameraController.get_safe_screen_rect() -> Rect2`.

- [ ] **Step 1: Write failing camera and controller tests**

```gdscript
var space := Control.new()
space.position = Vector2(248, 96)
space.size = Vector2(1300, 760)
var camera := CameraController.new()
camera.configure_bounds(Rect2(Vector2(80, 80), Vector2(520, 520)))
var layout := ResponsiveLayoutController.new()
layout.configure(space, camera)
assert_true(layout.refresh(Vector2(1920, 1080), true), "первая геометрия применяется")
assert_true(not layout.refresh(Vector2(1920, 1080)), "та же геометрия не пересчитывается")
assert_eq(layout.snapshot()[&"revision"], 1, "revision меняется только один раз")
assert_eq(camera.get_safe_screen_rect(), Rect2(Vector2(248, 96), Vector2(1300, 760)), "камера получает safe area")
```

For camera projection:

```gdscript
camera.configure_safe_view(Rect2(Vector2(248, 96), Vector2(1300, 760)), Vector2(1920, 1080), true)
var projected := (Vector2(340, 340) - camera.position) * camera.zoom.x + Vector2(960, 540)
assert_near(projected.x, 898.0, 0.01, "центр карты попадает в safe area по X")
assert_near(projected.y, 476.0, 0.01, "центр карты попадает в safe area по Y")
```

- [ ] **Step 2: Run both suites to verify RED**

Run each suite through `/private/tmp/run_godot_suite.gd`. Expected: missing classes/methods.

- [ ] **Step 3: Implement `ResponsiveLayoutController`**

```gdscript
class_name ResponsiveLayoutController
extends RefCounted

var _world_space: Control
var _camera: CameraController
var _world_rect := Rect2()
var _viewport_size := Vector2.ZERO
var _revision := 0

func configure(world_space: Control, camera: CameraController) -> void:
    _world_space = world_space
    _camera = camera

func refresh(viewport_size: Vector2, fit_world: bool = false) -> bool:
    if _world_space == null or _camera == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return false
    var next_rect := _world_space.get_global_rect()
    if next_rect.is_equal_approx(_world_rect) and viewport_size.is_equal_approx(_viewport_size):
        return false
    _world_rect = next_rect
    _viewport_size = viewport_size
    _revision += 1
    _camera.configure_safe_view(_world_rect, _viewport_size, fit_world)
    return true

func snapshot() -> Dictionary:
    return {&"world_rect": _world_rect, &"viewport_size": _viewport_size, &"revision": _revision}
```

- [ ] **Step 4: Implement safe centering in `CameraController`**

Store `_safe_screen_rect` and `_viewport_size`. For initial fit:

```gdscript
var fit_zoom := minf(screen_rect.size.x / _world_rect.size.x, screen_rect.size.y / _world_rect.size.y) * 0.88
set_zoom_factor(fit_zoom)
position = _world_rect.get_center() - (screen_rect.get_center() - viewport_size * 0.5) / zoom.x
reset_smoothing()
```

On later resize preserve zoom and only recenter.

- [ ] **Step 5: Run both suites to verify GREEN**

Expected: both targeted suites pass without script errors.

- [ ] **Step 6: Commit**

```bash
git add src/app/responsive_layout_controller.gd src/presentation/world/camera_controller.gd tests/unit/test_responsive_layout_controller.gd tests/unit/test_camera_controller.gd
git commit -m "feat: центрировать мир в безопасной области"
```

### Task 3: Контейнерный каркас главной сцены

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `src/app/main.gd`
- Create: `tests/integration/test_responsive_main_layout.gd`
- Modify: `tests/integration/test_stage5_ui.gd`
- Modify: `tests/integration/test_stage6_playtest_integration.gd`

**Interfaces:**
- Consumes: `ResponsiveLayoutController` from Task 2.
- Produces: node paths rooted at `UI/SafeArea/Shell`.
- Produces: `Main.get_layout_snapshot() -> Dictionary`.

- [ ] **Step 1: Write the failing scene-layout test**

```gdscript
var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
(Engine.get_main_loop() as SceneTree).root.add_child(instance)
var world_space := instance.get_node("UI/SafeArea/Shell/Body/Center/WorldSpace") as Control
var context := instance.get_node("UI/SafeArea/Shell/Body/Center/ContextPanel") as Control
var tools := instance.get_node("UI/SafeArea/Shell/Body/Center/BottomBar") as Control
var inspector := instance.get_node("UI/SafeArea/Shell/Body/RightPanel") as Control
assert_true(world_space.size.x >= 1100.0, "мир имеет полноразмерную ширину")
assert_true(world_space.size.y >= 720.0, "мир имеет полноразмерную высоту")
assert_true(not context.get_global_rect().intersects(tools.get_global_rect()), "подсказка не перекрывает инструменты")
assert_true(not context.get_global_rect().intersects(inspector.get_global_rect()), "подсказка не перекрывает инспектор")
assert_true(not tools.get_global_rect().intersects(inspector.get_global_rect()), "инструменты не перекрывают инспектор")
```

- [ ] **Step 2: Run the new suite to verify RED**

Expected: new hierarchy is absent and the old center is only `752 px` wide.

- [ ] **Step 3: Rebuild `main.tscn` with containers**

```text
UI (CanvasLayer)
└── SafeArea (MarginContainer, full rect, margins 12)
    └── Shell (VBoxContainer, separation 12)
        ├── TopBar (PanelContainer, min height 72)
        └── Body (HBoxContainer, expand, separation 12)
            ├── LeftPanel (PanelContainer, min width 224)
            ├── Center (VBoxContainer, expand, separation 12)
            │   ├── WorldSpace (Control, expand both, mouse_filter IGNORE)
            │   ├── ContextPanel (PanelContainer, min height 112)
            │   └── BottomBar (PanelContainer, min height 72)
            └── RightPanel (PanelContainer, min width 336)
```

Set hint/target to word-smart autowrap, make the copy column expand instead of fixed `540 px`, and give all six tool buttons equal horizontal expansion. Keep `ResultPanel` as a centered modal sibling of `SafeArea`.

- [ ] **Step 4: Rewire `main.gd` and resize handling**

```gdscript
var _responsive_layout := ResponsiveLayoutController.new()

func get_layout_snapshot() -> Dictionary:
    return _responsive_layout.snapshot()

func _refresh_responsive_layout(fit_world: bool = false) -> void:
    _responsive_layout.refresh(Vector2(get_viewport_rect().size), fit_world)
```

In `_ready()`, configure `UI/SafeArea/Shell/Body/Center/WorldSpace`, set `get_window().min_size = Vector2i(1280, 720)`, connect viewport `size_changed` to deferred refresh, configure camera bounds, then call the first refresh with `fit_world = true`. Remove hardcoded zoom `0.75`. Update all `$UI/...` paths and test paths without changing gameplay behavior.

- [ ] **Step 5: Run layout and existing UI suites to verify GREEN**

Run the new layout suite, `test_stage5_ui.gd`, and `test_stage6_playtest_integration.gd`. Expected: all pass and the simulation hash assertion remains green.

- [ ] **Step 6: Commit**

```bash
git add scenes/main.tscn src/app/main.gd tests/integration/test_responsive_main_layout.gd tests/integration/test_stage5_ui.gd tests/integration/test_stage6_playtest_integration.gd
git commit -m "feat: развернуть адаптивный HUD"
```

### Task 4: Недействительный PT-V01 и новая серия

**Files:**
- Create: `docs/playtests/PT-V01-invalid-summary.ru.md`
- Create: `tests/integration/test_stage6_docs.gd`
- Modify: `docs/playtests/observer-guide.md`
- Modify: `docs/stages/06-playtest-and-art-pass.md`
- Modify: `docs/playtests/summary-template.md`

**Interfaces:**
- Produces: replacement IDs `PT-R01`…`PT-R05` for one new immutable build.
- Consumes: local `PT-V01-report.ru.md` as diagnostic evidence; raw JSON is never committed.

- [ ] **Step 1: Write the failing documentation test**

```gdscript
var stage_text := FileAccess.get_file_as_string("res://docs/stages/06-playtest-and-art-pass.md")
var summary_text := FileAccess.get_file_as_string("res://docs/playtests/summary-template.md")
assert_true(stage_text.contains("PT-R01"), "этап указывает новую серию")
assert_true(stage_text.contains("технически недействитель"), "PT-V01 исключён из результатов")
assert_true(not summary_text.contains("PT-V01 |"), "невалидная сессия не занимает строку серии")
```

- [ ] **Step 2: Run the docs suite to verify RED**

Expected: FAIL because the old ID sequence remains and the invalid summary is missing.

- [ ] **Step 3: Write the diagnostic and update protocol**

Record build `ed184df`, outcome `aborted`, time `05:29`, user-observed overlap/compression, root cause `1280×720` absolute layout, and decision to exclude the session without gameplay inference. Update observer guide, stage status and summary rows to `PT-R01`…`PT-R05`. Do not commit raw timeline or personal data.

- [ ] **Step 4: Run the docs suite to verify GREEN**

Expected: suite passes and Git tracks no `PT-V01.json` or generated report.

- [ ] **Step 5: Commit**

```bash
git add docs/playtests/PT-V01-invalid-summary.ru.md docs/playtests/observer-guide.md docs/stages/06-playtest-and-art-pass.md docs/playtests/summary-template.md tests/integration/test_stage6_docs.gd
git commit -m "docs: перезапустить серию после дефекта HUD"
```

### Task 5: Приёмка полноразмерного прототипа

**Files:**
- No planned file changes. If acceptance fails, return to the task that owns the failing behavior, add a regression assertion there, and commit that fix before continuing.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: new immutable candidate SHA for `PT-R01`…`PT-R05`.

- [ ] **Step 1: Run targeted acceptance**

Run responsive layout, camera, stage 5 UI, stage 6 integration and docs suites. Expected: all pass without script errors.

- [ ] **Step 2: Run the complete project gate**

```bash
./scripts/check_project.sh
```

Expected: import, all suites and smoke pass; road and water metrics remain unchanged.

- [ ] **Step 3: Perform a short visual check at two sizes**

Capture and inspect maximized neutral screen, resized `1280×720`, pipe mode with confirm/cancel, and a selected building with right inspector populated. Acceptance: world is dominant, Russian text is readable, context/tools/inspector do not intersect, no control is clipped. Stop Godot after the check; do not record video.

- [ ] **Step 4: Verify clean Git scope**

```bash
git diff --check ed184df...HEAD
git status --short
git ls-files | rg 'PT-V01\.json|PT-V01-report'
```

Expected: clean diff/status and no raw playtest files.

- [ ] **Step 5: Review, merge and push**

Review `git diff ed184df...HEAD`, fast-forward into `main`, verify merged SHA, push `origin main`, then remove the worktree and local feature branch.

- [ ] **Step 6: Start replacement session only after handoff**

```bash
./scripts/run_playtest.sh PT-R01
```

Do not start until the new SHA is pushed and a new participant is ready. The observer states only the approved goal.
