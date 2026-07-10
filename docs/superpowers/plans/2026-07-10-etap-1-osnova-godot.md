# Этап 1: основа Godot-прототипа — план реализации

> **Для агентных исполнителей:** ОБЯЗАТЕЛЬНЫЙ ПОДНАВЫК: использовать `superpowers:subagent-driven-development` (рекомендуется) или `superpowers:executing-plans` и выполнять план по задачам. Для отслеживания используются флажки `- [ ]`.

**Цель:** создать запускаемый Godot 4.6.2-проект с русской базовой локалью, собственным headless-раннером тестов, типизированной моделью гексов, картой 18×18, камерой и выбором клетки.

**Архитектура:** модель гексов и преобразование координат реализуются как чистые `RefCounted`-классы без зависимости от дерева сцен. `HexGridView` только рисует переданную модель и преобразует ввод в типизированный сигнал. Главная сцена связывает модель, представление, камеру и локализованный HUD.

**Технологии:** Godot 4.6.2 stable, статически типизированный GDScript, встроенный `TranslationServer`, CSV-каталог переводов, собственные headless-тесты без сторонних addons, Git.

## Глобальные ограничения

- Исходный язык интерфейса и проверяемой документации — русский.
- Технические идентификаторы, имена файлов, классов и ключей локализации — английские, латиницей.
- Пользовательские строки вызываются только через `tr()`/`TranslationServer`; жёстко зашитый русский текст в GDScript и `.tscn` запрещён.
- Базовая локаль — `ru`; каталог `localization/game.csv` допускает добавление языков без изменения кода.
- Симуляционная модель не импортирует типы представления Godot.
- В этапе 1 нет рабочих, логистики, зданий, ресурсов и игрового сценария: они начинаются только после прохождения gate этого плана.
- Для всех команд ниже используется бинарник `/Applications/Godot.app/Contents/MacOS/Godot`.
- Каждый этап изменения кода начинается с падающего теста, заканчивается зелёной проверкой и отдельным коммитом.

## Карта файлов этапа

```text
project.godot                                  # настройки проекта, локали, окна и главной сцены
localization/game.csv                         # семантические ключи, русский и тестовый английский
src/simulation/model/hex_coord.gd             # аксиальная координата и операции над ней
src/simulation/model/hex_cell_state.gd        # состояние одного гекса
src/simulation/model/hex_map_state.gd         # прямоугольная аксиальная карта
src/presentation/world/hex_layout.gd           # перевод coord ↔ pixel и геометрия шестиугольника
src/presentation/world/hex_grid_view.gd        # рисование карты и выбор гекса
src/presentation/world/camera_controller.gd    # перетаскивание, масштаб и границы камеры
src/app/main.gd                                # composition root этапа 1
scenes/main.tscn                              # главная сцена мира и HUD
tests/test_case.gd                            # минимальные проверки и накопление ошибок
tests/run_tests.gd                            # автоматическое обнаружение и запуск suites
tests/unit/test_localization.gd               # русская локаль и кириллица
tests/unit/test_hex_coord.gd                   # операции аксиальной координаты
tests/unit/test_hex_map_state.gd               # границы и соседи карты
tests/unit/test_hex_layout.gd                  # геометрия и round-trip координат
tests/unit/test_camera_controller.gd           # ограничения масштаба и границ
tests/integration/test_hex_grid_view.gd        # выбор клетки через представление
tests/integration/test_main_scene.gd           # сборка главной сцены
tests/integration/test_project_configuration.gd # настройки и полнота локализации
scripts/check_project.sh                      # единая локальная проверка
README.md                                     # русскоязычный запуск и структура этапа
```

---

### Задача 1: проект, тестовый раннер и локализация

**Файлы:**
- Создать: `project.godot`
- Создать: `tests/test_case.gd`
- Создать: `tests/run_tests.gd`
- Создать: `tests/unit/test_localization.gd`
- Создать: `localization/game.csv`

**Интерфейсы:**
- Создаёт `TestCase.assert_eq()`, `TestCase.assert_true()`, `TestCase.assert_near()` и `TestCase.finish()` для всех последующих тестов.
- Создаёт команду запуска `godot --headless --path . --script res://tests/run_tests.gd`.
- Создаёт ключи `ui.app.title`, `ui.status.select_hex`, `ui.status.selected_hex`.

- [ ] **Шаг 1: создать минимальный проект, тестовый раннер и падающий тест локализации**

Создать `project.godot` без подключённого каталога переводов:

```ini
; Engine configuration file.
; It is best edited using the editor and kept under version control.

config_version=5

[application]

config/name="Паровая логистика"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[internationalization]

locale/fallback="ru"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Создать `tests/test_case.gd`:

```gdscript
class_name TestCase
extends RefCounted

var _failures: Array[String] = []


func assert_true(value: bool, message: String) -> void:
    if not value:
        _failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        _failures.append(
            "%s; ожидалось=%s, получено=%s" % [message, var_to_str(expected), var_to_str(actual)]
        )


func assert_near(actual: float, expected: float, epsilon: float, message: String) -> void:
    if absf(actual - expected) > epsilon:
        _failures.append(
            "%s; ожидалось≈%f, получено=%f" % [message, expected, actual]
        )


func finish() -> Array[String]:
    return _failures.duplicate()
```

Создать `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TEST_ROOT := "res://tests"


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var failures: Array[String] = []
    var suites := _discover_suites(TEST_ROOT)

    for suite_path in suites:
        var suite_script := load(suite_path) as Script
        if suite_script == null:
            failures.append("%s: файл теста не загружен" % suite_path)
            continue

        var suite: Variant = suite_script.new()
        if not suite.has_method("run"):
            failures.append("%s: отсутствует метод run()" % suite_path)
            continue

        var suite_failures: Array = suite.call("run")
        for failure in suite_failures:
            failures.append("%s: %s" % [suite_path, str(failure)])

    if failures.is_empty():
        print("TESTS PASSED: %d suites" % suites.size())
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    print("TESTS FAILED: %d failures" % failures.size())
    quit(1)


func _discover_suites(root_path: String) -> Array[String]:
    var result: Array[String] = []

    for file_name in DirAccess.get_files_at(root_path):
        if file_name.begins_with("test_") and file_name.ends_with(".gd"):
            result.append(root_path.path_join(file_name))

    for directory_name in DirAccess.get_directories_at(root_path):
        if not directory_name.begins_with("."):
            result.append_array(_discover_suites(root_path.path_join(directory_name)))

    result.sort()
    return result
```

Создать `tests/unit/test_localization.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    TranslationServer.set_locale("ru")
    assert_eq(
        TranslationServer.translate(&"ui.app.title"),
        &"Паровая логистика",
        "заголовок должен переводиться на русский"
    )
    assert_true(
        ThemeDB.fallback_font.has_char("Ж".unicode_at(0)),
        "fallback-шрифт Godot должен содержать кириллицу"
    )
    return finish()
```

- [ ] **Шаг 2: запустить тест и подтвердить ожидаемое падение**

Выполнить:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: exit code `1`, сообщение содержит `заголовок должен переводиться на русский`, потому что `ui.app.title` пока возвращается как ключ.

- [ ] **Шаг 3: добавить каталог переводов и подключить его к проекту**

Создать `localization/game.csv`:

```csv
keys,ru,en
ui.app.title,Паровая логистика,Steam Logistics
ui.status.select_hex,Выберите гекс,Select a hex
ui.status.selected_hex,"Выбран гекс: {q}, {r}","Selected hex: {q}, {r}"
```

Заменить `project.godot` полной финальной версией задачи:

```ini
; Engine configuration file.
; It is best edited using the editor and kept under version control.

config_version=5

[application]

config/name="Паровая логистика"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[internationalization]

locale/fallback="ru"
locale/translations=PackedStringArray("res://localization/game.csv")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Шаг 4: импортировать CSV и подтвердить зелёный тест**

Выполнить:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --import
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: импорт завершается без ошибок; тесты печатают `TESTS PASSED: 1 suites` и возвращают exit code `0`.

- [ ] **Шаг 5: закоммитить основу**

```bash
git add project.godot localization/game.csv tests/test_case.gd tests/run_tests.gd tests/unit/test_localization.gd
git commit -m "build: создать Godot-проект и локализацию"
```

---

### Задача 2: аксиальная координата гекса

**Файлы:**
- Создать: `tests/unit/test_hex_coord.gd`
- Создать: `src/simulation/model/hex_coord.gd`

**Интерфейсы:**
- Создаёт `HexCoord.new(q: int, r: int)`.
- Создаёт `s`, `neighbor(direction)`, `neighbors()`, `distance_to(other)`, `key()` и `equals(other)`.
- Все последующие классы используют `HexCoord`, а не `Vector2i`, как доменный тип координаты.

- [ ] **Шаг 1: написать падающие тесты соседей, расстояния и ключа**

Создать `tests/unit/test_hex_coord.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var origin := HexCoord.new(0, 0)
    var neighbors := origin.neighbors()

    assert_eq(neighbors.size(), 6, "у гекса должно быть шесть направлений")
    assert_true(neighbors[0].equals(HexCoord.new(1, 0)), "направление 0 должно вести на восток")
    assert_true(neighbors[2].equals(HexCoord.new(0, -1)), "направление 2 должно вести на северо-запад")
    assert_eq(origin.s, 0, "кубическая координата s начала должна быть нулевой")
    assert_eq(HexCoord.new(3, -2).s, -1, "s должна вычисляться как -q-r")
    assert_eq(origin.distance_to(HexCoord.new(3, -2)), 3, "расстояние должно быть кубическим")
    assert_eq(HexCoord.new(-4, 7).key(), &"-4:7", "ключ должен быть стабильным")
    return finish()
```

- [ ] **Шаг 2: запустить тест и увидеть ошибку отсутствующего `HexCoord`**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: parser error сообщает, что `HexCoord` не объявлен.

- [ ] **Шаг 3: реализовать минимальный тип координаты**

Создать `src/simulation/model/hex_coord.gd`:

```gdscript
class_name HexCoord
extends RefCounted

const DIRECTIONS := [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

var q: int
var r: int
var s: int:
    get:
        return -q - r


func _init(p_q: int = 0, p_r: int = 0) -> void:
    q = p_q
    r = p_r


func neighbor(direction: int) -> HexCoord:
    assert(direction >= 0 and direction < DIRECTIONS.size())
    var offset: Vector2i = DIRECTIONS[direction]
    return HexCoord.new(q + offset.x, r + offset.y)


func neighbors() -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for direction in DIRECTIONS.size():
        result.append(neighbor(direction))
    return result


func distance_to(other: HexCoord) -> int:
    return int((absi(q - other.q) + absi(r - other.r) + absi(s - other.s)) / 2)


func key() -> StringName:
    return StringName("%d:%d" % [q, r])


func equals(other: HexCoord) -> bool:
    return other != null and q == other.q and r == other.r
```

- [ ] **Шаг 4: запустить весь набор тестов**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: `TESTS PASSED: 2 suites`.

- [ ] **Шаг 5: закоммитить координату**

```bash
git add src/simulation/model/hex_coord.gd tests/unit/test_hex_coord.gd
git commit -m "feat: добавить аксиальные координаты гексов"
```

---

### Задача 3: состояние клетки и карты

**Файлы:**
- Создать: `tests/unit/test_hex_map_state.gd`
- Создать: `src/simulation/model/hex_cell_state.gd`
- Создать: `src/simulation/model/hex_map_state.gd`

**Интерфейсы:**
- Создаёт `HexCellState.coord`, `traversable` и `movement_cost`.
- Создаёт `HexMapState.new(width, height)`, `contains()`, `get_cell()`, `get_neighbors()`, `set_movement_cost()` и `cell_count()`.
- Карта этапа 1 — аксиальный прямоугольник `q=0..width-1`, `r=0..height-1`.

- [ ] **Шаг 1: написать тесты границ, соседей и стоимости движения**

Создать `tests/unit/test_hex_map_state.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var map_state := HexMapState.new(18, 18)

    assert_eq(map_state.cell_count(), 324, "карта 18×18 должна содержать 324 гекса")
    assert_true(map_state.contains(HexCoord.new(0, 0)), "левый верхний гекс должен существовать")
    assert_true(map_state.contains(HexCoord.new(17, 17)), "правый нижний гекс должен существовать")
    assert_true(not map_state.contains(HexCoord.new(-1, 0)), "отрицательный q должен быть вне карты")
    assert_true(not map_state.contains(HexCoord.new(18, 0)), "q за правой границей должен быть вне карты")
    assert_eq(map_state.get_neighbors(HexCoord.new(0, 0)).size(), 2, "угловой гекс имеет двух соседей внутри карты")
    assert_eq(map_state.get_neighbors(HexCoord.new(8, 8)).size(), 6, "внутренний гекс имеет шесть соседей")

    assert_true(map_state.set_movement_cost(HexCoord.new(2, 3), 4), "стоимость существующего гекса должна изменяться")
    assert_eq(map_state.get_cell(HexCoord.new(2, 3)).movement_cost, 4, "новая стоимость должна сохраниться")
    assert_true(not map_state.set_movement_cost(HexCoord.new(30, 30), 4), "изменение вне карты должно отклоняться")
    return finish()
```

- [ ] **Шаг 2: подтвердить падение из-за отсутствующего `HexMapState`**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: parser error сообщает, что `HexMapState` не объявлен.

- [ ] **Шаг 3: реализовать состояние гекса**

Создать `src/simulation/model/hex_cell_state.gd`:

```gdscript
class_name HexCellState
extends RefCounted

var coord: HexCoord
var traversable: bool = true
var movement_cost: int = 1


func _init(p_coord: HexCoord) -> void:
    coord = p_coord
```

- [ ] **Шаг 4: реализовать карту**

Создать `src/simulation/model/hex_map_state.gd`:

```gdscript
class_name HexMapState
extends RefCounted

var width: int
var height: int
var _cells: Dictionary = {}


func _init(p_width: int, p_height: int) -> void:
    assert(p_width > 0 and p_height > 0)
    width = p_width
    height = p_height

    for q in width:
        for r in height:
            var coord := HexCoord.new(q, r)
            _cells[coord.key()] = HexCellState.new(coord)


func cell_count() -> int:
    return _cells.size()


func contains(coord: HexCoord) -> bool:
    return coord != null and _cells.has(coord.key())


func get_cell(coord: HexCoord) -> HexCellState:
    if not contains(coord):
        return null
    return _cells[coord.key()] as HexCellState


func get_neighbors(coord: HexCoord) -> Array[HexCellState]:
    var result: Array[HexCellState] = []
    if not contains(coord):
        return result

    for neighbor_coord in coord.neighbors():
        var cell := get_cell(neighbor_coord)
        if cell != null:
            result.append(cell)
    return result


func set_movement_cost(coord: HexCoord, cost: int) -> bool:
    var cell := get_cell(coord)
    if cell == null or cost < 1:
        return false
    cell.movement_cost = cost
    return true
```

- [ ] **Шаг 5: запустить тесты модели**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: `TESTS PASSED: 3 suites`.

- [ ] **Шаг 6: закоммитить модель карты**

```bash
git add src/simulation/model/hex_cell_state.gd src/simulation/model/hex_map_state.gd tests/unit/test_hex_map_state.gd
git commit -m "feat: добавить модель гексагональной карты"
```

---

### Задача 4: геометрия flat-top гексов

**Файлы:**
- Создать: `tests/unit/test_hex_layout.gd`
- Создать: `src/presentation/world/hex_layout.gd`

**Интерфейсы:**
- Создаёт `HexLayout.new(hex_size, origin)`.
- Создаёт `coord_to_pixel()`, `pixel_to_coord()` и `polygon_corners()`.
- Ориентация фиксируется как flat-top; `HexGridView` и ввод используют один экземпляр `HexLayout`.

- [ ] **Шаг 1: написать round-trip тест и тест размеров**

Создать `tests/unit/test_hex_layout.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var layout := HexLayout.new(32.0, Vector2(10.0, 20.0))
    var coord := HexCoord.new(4, 7)
    var pixel := layout.coord_to_pixel(coord)
    var restored := layout.pixel_to_coord(pixel)

    assert_true(restored.equals(coord), "центр гекса должен преобразовываться обратно в ту же координату")
    assert_near(layout.coord_to_pixel(HexCoord.new(1, 0)).x, 58.0, 0.001, "шаг flat-top по q должен быть 1.5 радиуса")
    assert_near(layout.coord_to_pixel(HexCoord.new(0, 0)).y, 20.0, 0.001, "origin должен смещать центр нулевого гекса")

    var corners := layout.polygon_corners(HexCoord.new(0, 0))
    assert_eq(corners.size(), 6, "полигон гекса должен иметь шесть вершин")
    assert_near(corners[0].distance_to(Vector2(10.0, 20.0)), 32.0, 0.001, "вершины должны находиться на заданном радиусе")

    for q in range(-3, 4):
        for r in range(-3, 4):
            var sample := HexCoord.new(q, r)
            assert_true(
                layout.pixel_to_coord(layout.coord_to_pixel(sample)).equals(sample),
                "round-trip должен работать для %s" % sample.key()
            )
    return finish()
```

- [ ] **Шаг 2: подтвердить падение из-за отсутствующего `HexLayout`**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: parser error сообщает, что `HexLayout` не объявлен.

- [ ] **Шаг 3: реализовать преобразования и округление кубических координат**

Создать `src/presentation/world/hex_layout.gd`:

```gdscript
class_name HexLayout
extends RefCounted

const SQRT_3 := 1.7320508075688772

var hex_size: float
var origin: Vector2


func _init(p_hex_size: float = 32.0, p_origin: Vector2 = Vector2.ZERO) -> void:
    assert(p_hex_size > 0.0)
    hex_size = p_hex_size
    origin = p_origin


func coord_to_pixel(coord: HexCoord) -> Vector2:
    return origin + Vector2(
        hex_size * 1.5 * coord.q,
        hex_size * SQRT_3 * (coord.r + coord.q * 0.5)
    )


func pixel_to_coord(pixel: Vector2) -> HexCoord:
    var local := pixel - origin
    var fractional_q := (2.0 / 3.0 * local.x) / hex_size
    var fractional_r := (-1.0 / 3.0 * local.x + SQRT_3 / 3.0 * local.y) / hex_size
    return _round_axial(fractional_q, fractional_r)


func polygon_corners(coord: HexCoord) -> PackedVector2Array:
    var center := coord_to_pixel(coord)
    var points := PackedVector2Array()
    for index in 6:
        var angle := deg_to_rad(60.0 * index)
        points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
    return points


func _round_axial(fractional_q: float, fractional_r: float) -> HexCoord:
    var fractional_s := -fractional_q - fractional_r
    var rounded_q := roundi(fractional_q)
    var rounded_r := roundi(fractional_r)
    var rounded_s := roundi(fractional_s)
    var q_difference := absf(rounded_q - fractional_q)
    var r_difference := absf(rounded_r - fractional_r)
    var s_difference := absf(rounded_s - fractional_s)

    if q_difference > r_difference and q_difference > s_difference:
        rounded_q = -rounded_r - rounded_s
    elif r_difference > s_difference:
        rounded_r = -rounded_q - rounded_s

    return HexCoord.new(rounded_q, rounded_r)
```

- [ ] **Шаг 4: запустить тесты геометрии**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: `TESTS PASSED: 4 suites`.

- [ ] **Шаг 5: закоммитить layout**

```bash
git add src/presentation/world/hex_layout.gd tests/unit/test_hex_layout.gd
git commit -m "feat: добавить геометрию flat-top гексов"
```

---

### Задача 5: отображение карты, главная сцена и выбор клетки

**Файлы:**
- Создать: `tests/integration/test_hex_grid_view.gd`
- Создать: `tests/integration/test_main_scene.gd`
- Создать: `src/presentation/world/hex_grid_view.gd`
- Создать: `src/app/main.gd`
- Создать: `scenes/main.tscn`
- Изменить: `project.godot`

**Интерфейсы:**
- Создаёт сигнал `HexGridView.hex_selected(coord: HexCoord)`.
- Создаёт `configure(map_state, layout)`, `select_at_local_position()`, `get_selected_coord()` и `get_world_rect()`.
- `Main` является composition root и единственным владельцем созданных на старте `HexMapState` и `HexLayout`.

- [ ] **Шаг 1: написать падающий интеграционный тест представления**

Создать `tests/integration/test_hex_grid_view.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var script_path := "res://src/presentation/world/hex_grid_view.gd"
    assert_true(ResourceLoader.exists(script_path), "скрипт HexGridView должен существовать")
    if not ResourceLoader.exists(script_path):
        return finish()

    var view: Variant = load(script_path).new()
    var map_state := HexMapState.new(18, 18)
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    view.configure(map_state, layout)

    var target := HexCoord.new(3, 4)
    assert_true(view.select_at_local_position(layout.coord_to_pixel(target)), "центр существующего гекса должен выбираться")
    assert_true(view.get_selected_coord().equals(target), "выбранная координата должна совпасть с целью")
    assert_true(not view.select_at_local_position(layout.coord_to_pixel(HexCoord.new(30, 30))), "позиция вне карты должна отклоняться")
    view.free()
    return finish()
```

Создать `tests/integration/test_main_scene.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var scene_path := "res://scenes/main.tscn"
    assert_true(ResourceLoader.exists(scene_path), "главная сцена должна существовать")
    if not ResourceLoader.exists(scene_path):
        return finish()

    TranslationServer.set_locale("ru")
    var packed_scene := load(scene_path) as PackedScene
    var instance := packed_scene.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)

    assert_true(instance.has_node("World/HexGridView"), "сцена должна содержать HexGridView")
    assert_eq(instance.get_node("UI/Margin/VBox/Title").text, "Паровая логистика", "заголовок должен быть локализован")
    assert_eq(instance.get_node("UI/Margin/VBox/Status").text, "Выберите гекс", "статус должен быть локализован")
    instance.free()
    return finish()
```

- [ ] **Шаг 2: запустить тесты и подтвердить два ожидаемых отказа**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: exit code `1`; ошибки сообщают об отсутствии `HexGridView` и главной сцены.

- [ ] **Шаг 3: реализовать рисование и выбор гекса**

Создать `src/presentation/world/hex_grid_view.gd`:

```gdscript
class_name HexGridView
extends Node2D

signal hex_selected(coord: HexCoord)

const CELL_COLOR_A := Color("#34493d")
const CELL_COLOR_B := Color("#3d5345")
const OUTLINE_COLOR := Color("#788777")
const SELECTED_COLOR := Color("#d69a4a")

var _map_state: HexMapState
var _layout: HexLayout
var _selected_coord: HexCoord


func configure(map_state: HexMapState, layout: HexLayout) -> void:
    _map_state = map_state
    _layout = layout
    queue_redraw()


func select_at_local_position(local_position: Vector2) -> bool:
    if _map_state == null or _layout == null:
        return false

    var coord := _layout.pixel_to_coord(local_position)
    if not _map_state.contains(coord):
        return false

    _selected_coord = coord
    queue_redraw()
    hex_selected.emit(coord)
    return true


func get_selected_coord() -> HexCoord:
    return _selected_coord


func get_world_rect() -> Rect2:
    if _map_state == null or _layout == null:
        return Rect2()

    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    for q in _map_state.width:
        for r in _map_state.height:
            for point in _layout.polygon_corners(HexCoord.new(q, r)):
                minimum.x = minf(minimum.x, point.x)
                minimum.y = minf(minimum.y, point.y)
                maximum.x = maxf(maximum.x, point.x)
                maximum.y = maxf(maximum.y, point.y)
    return Rect2(minimum + position, maximum - minimum)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            if select_at_local_position(to_local(get_global_mouse_position())):
                get_viewport().set_input_as_handled()


func _draw() -> void:
    if _map_state == null or _layout == null:
        return

    for q in _map_state.width:
        for r in _map_state.height:
            var coord := HexCoord.new(q, r)
            var points := _layout.polygon_corners(coord)
            var fill := CELL_COLOR_A if (q + r) % 2 == 0 else CELL_COLOR_B
            draw_colored_polygon(points, fill)
            draw_polyline(_closed_polygon(points), OUTLINE_COLOR, 1.0, true)

            if _selected_coord != null and _selected_coord.equals(coord):
                draw_polyline(_closed_polygon(points), SELECTED_COLOR, 4.0, true)


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
    var result := points.duplicate()
    result.append(points[0])
    return result
```

- [ ] **Шаг 4: создать composition root и локализованный HUD**

Создать `src/app/main.gd`:

```gdscript
extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var title_label: Label = $UI/Margin/VBox/Title
@onready var status_label: Label = $UI/Margin/VBox/Status


func _ready() -> void:
    TranslationServer.set_locale("ru")
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")

    var map_state := HexMapState.new(18, 18)
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(map_state, layout)
    grid_view.hex_selected.connect(_on_hex_selected)


func _on_hex_selected(coord: HexCoord) -> void:
    status_label.text = tr(&"ui.status.selected_hex").format({"q": coord.q, "r": coord.r})
```

Создать `scenes/main.tscn`:

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/app/main.gd" id="1_main"]
[ext_resource type="Script" path="res://src/presentation/world/hex_grid_view.gd" id="2_grid"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="Background" type="CanvasLayer" parent="."]
layer = -10

[node name="Color" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.075, 0.094, 0.102, 1)

[node name="World" type="Node2D" parent="."]

[node name="HexGridView" type="Node2D" parent="World"]
position = Vector2(80, 80)
script = ExtResource("2_grid")

[node name="UI" type="CanvasLayer" parent="."]
layer = 10

[node name="Margin" type="MarginContainer" parent="UI"]
offset_left = 20.0
offset_top = 20.0
offset_right = 380.0
offset_bottom = 112.0

[node name="VBox" type="VBoxContainer" parent="UI/Margin"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Title" type="Label" parent="UI/Margin/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.94, 0.76, 0.47, 1)
theme_override_font_sizes/font_size = 24
text = "ui.app.title"

[node name="Status" type="Label" parent="UI/Margin/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.84, 0.87, 0.88, 1)
theme_override_font_sizes/font_size = 18
text = "ui.status.select_hex"
```

Заменить `project.godot` полной финальной версией задачи:

```ini
; Engine configuration file.
; It is best edited using the editor and kept under version control.

config_version=5

[application]

config/name="Паровая логистика"
run/main_scene="res://scenes/main.tscn"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[internationalization]

locale/fallback="ru"
locale/translations=PackedStringArray("res://localization/game.csv")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Шаг 5: импортировать проект, запустить тесты и smoke run**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --import
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 2
```

Ожидание: тесты печатают `TESTS PASSED: 6 suites`; smoke run завершается без `SCRIPT ERROR`, `Parse Error` и отсутствующих ресурсов.

- [ ] **Шаг 6: закоммитить карту и сцену**

```bash
git add project.godot scenes/main.tscn src/app/main.gd src/presentation/world/hex_grid_view.gd tests/integration/test_hex_grid_view.gd tests/integration/test_main_scene.gd
git commit -m "feat: отобразить карту и выбор гекса"
```

---

### Задача 6: камера с перетаскиванием, масштабом и границами

**Файлы:**
- Создать: `tests/unit/test_camera_controller.gd`
- Создать: `src/presentation/world/camera_controller.gd`
- Изменить: `src/app/main.gd`
- Изменить: `scenes/main.tscn`

**Интерфейсы:**
- Создаёт `CameraController.set_zoom_factor(value)` и `configure_bounds(world_rect)`.
- Средняя кнопка мыши перемещает камеру; колёсико меняет масштаб в пределах `0.5..2.0`.
- `Main` передаёт камере границы, рассчитанные `HexGridView.get_world_rect()`.

- [ ] **Шаг 1: написать падающий тест ограничений камеры**

Создать `tests/unit/test_camera_controller.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    var script_path := "res://src/presentation/world/camera_controller.gd"
    assert_true(ResourceLoader.exists(script_path), "скрипт CameraController должен существовать")
    if not ResourceLoader.exists(script_path):
        return finish()

    var camera: Variant = load(script_path).new()
    camera.set_zoom_factor(9.0)
    assert_eq(camera.zoom, Vector2(2.0, 2.0), "масштаб должен ограничиваться максимумом")
    camera.set_zoom_factor(0.1)
    assert_eq(camera.zoom, Vector2(0.5, 0.5), "масштаб должен ограничиваться минимумом")

    camera.configure_bounds(Rect2(Vector2(-40, -20), Vector2(900, 1200)))
    assert_eq(camera.limit_left, -40, "левая граница должна совпасть с картой")
    assert_eq(camera.limit_bottom, 1180, "нижняя граница должна совпасть с картой")
    assert_eq(camera.position, Vector2(410, 580), "камера должна центрироваться по карте")
    camera.free()
    return finish()
```

- [ ] **Шаг 2: подтвердить падение из-за отсутствующего контроллера**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: exit code `1`, сообщение `скрипт CameraController должен существовать`.

- [ ] **Шаг 3: реализовать контроллер камеры**

Создать `src/presentation/world/camera_controller.gd`:

```gdscript
class_name CameraController
extends Camera2D

@export var minimum_zoom: float = 0.5
@export var maximum_zoom: float = 2.0
@export var zoom_step: float = 1.15

var _dragging: bool = false


func set_zoom_factor(value: float) -> void:
    var clamped := clampf(value, minimum_zoom, maximum_zoom)
    zoom = Vector2.ONE * clamped


func configure_bounds(world_rect: Rect2) -> void:
    limit_left = floori(world_rect.position.x)
    limit_top = floori(world_rect.position.y)
    limit_right = ceili(world_rect.end.x)
    limit_bottom = ceili(world_rect.end.y)
    position = world_rect.get_center()
    reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        match mouse_event.button_index:
            MOUSE_BUTTON_MIDDLE:
                _dragging = mouse_event.pressed
                get_viewport().set_input_as_handled()
            MOUSE_BUTTON_WHEEL_UP:
                if mouse_event.pressed:
                    set_zoom_factor(zoom.x * zoom_step)
                    get_viewport().set_input_as_handled()
            MOUSE_BUTTON_WHEEL_DOWN:
                if mouse_event.pressed:
                    set_zoom_factor(zoom.x / zoom_step)
                    get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _dragging:
        var motion_event := event as InputEventMouseMotion
        position -= motion_event.relative / zoom.x
        get_viewport().set_input_as_handled()
```

- [ ] **Шаг 4: подключить камеру к composition root**

Заменить `src/app/main.gd` полной версией:

```gdscript
extends Node2D

@onready var grid_view: HexGridView = $World/HexGridView
@onready var camera_controller: CameraController = $CameraController
@onready var title_label: Label = $UI/Margin/VBox/Title
@onready var status_label: Label = $UI/Margin/VBox/Status


func _ready() -> void:
    TranslationServer.set_locale("ru")
    title_label.text = tr(&"ui.app.title")
    status_label.text = tr(&"ui.status.select_hex")

    var map_state := HexMapState.new(18, 18)
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    grid_view.configure(map_state, layout)
    grid_view.hex_selected.connect(_on_hex_selected)

    camera_controller.configure_bounds(grid_view.get_world_rect().grow(64.0))
    camera_controller.set_zoom_factor(0.75)


func _on_hex_selected(coord: HexCoord) -> void:
    status_label.text = tr(&"ui.status.selected_hex").format({"q": coord.q, "r": coord.r})
```

Заменить `scenes/main.tscn` полной версией:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/app/main.gd" id="1_main"]
[ext_resource type="Script" path="res://src/presentation/world/hex_grid_view.gd" id="2_grid"]
[ext_resource type="Script" path="res://src/presentation/world/camera_controller.gd" id="3_camera"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="CameraController" type="Camera2D" parent="."]
position = Vector2(640, 360)
enabled = true
position_smoothing_enabled = true
position_smoothing_speed = 8.0
script = ExtResource("3_camera")

[node name="Background" type="CanvasLayer" parent="."]
layer = -10

[node name="Color" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.075, 0.094, 0.102, 1)

[node name="World" type="Node2D" parent="."]

[node name="HexGridView" type="Node2D" parent="World"]
position = Vector2(80, 80)
script = ExtResource("2_grid")

[node name="UI" type="CanvasLayer" parent="."]
layer = 10

[node name="Margin" type="MarginContainer" parent="UI"]
offset_left = 20.0
offset_top = 20.0
offset_right = 380.0
offset_bottom = 112.0

[node name="VBox" type="VBoxContainer" parent="UI/Margin"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Title" type="Label" parent="UI/Margin/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.94, 0.76, 0.47, 1)
theme_override_font_sizes/font_size = 24
text = "ui.app.title"

[node name="Status" type="Label" parent="UI/Margin/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.84, 0.87, 0.88, 1)
theme_override_font_sizes/font_size = 18
text = "ui.status.select_hex"
```

- [ ] **Шаг 5: выполнить тесты и smoke run**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --import
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 2
```

Ожидание: `TESTS PASSED: 7 suites`; smoke run без ошибок.

- [ ] **Шаг 6: закоммитить камеру**

```bash
git add scenes/main.tscn src/app/main.gd src/presentation/world/camera_controller.gd tests/unit/test_camera_controller.gd
git commit -m "feat: добавить управление камерой"
```

---

### Задача 7: единая проверка, конфигурационные тесты и русская документация

**Файлы:**
- Создать: `tests/integration/test_project_configuration.gd`
- Создать: `scripts/check_project.sh`
- Создать: `README.md`

**Интерфейсы:**
- Создаёт единую команду `scripts/check_project.sh` для импорта, тестов и smoke run.
- Проверяет базовую локаль, подключённый CSV, полноту русского столбца и тестовое переключение на `en`.
- Документирует на русском текущий объём и управление.

- [ ] **Шаг 1: написать конфигурационный тест**

Создать `tests/integration/test_project_configuration.gd`:

```gdscript
extends TestCase


func run() -> Array[String]:
    assert_eq(
        ProjectSettings.get_setting("internationalization/locale/fallback"),
        "ru",
        "базовая локаль должна быть русской"
    )
    assert_eq(
        ProjectSettings.get_setting("application/run/main_scene"),
        "res://scenes/main.tscn",
        "главная сцена должна быть настроена"
    )
    assert_eq(
        ProjectSettings.get_setting("display/window/size/viewport_width"),
        1280,
        "ширина viewport должна быть 1280"
    )

    var translation_paths: PackedStringArray = ProjectSettings.get_setting(
        "internationalization/locale/translations",
        PackedStringArray()
    )
    assert_true(
        translation_paths.has("res://localization/game.csv"),
        "каталог game.csv должен загружаться проектом"
    )
    _assert_catalog_complete("res://localization/game.csv")

    TranslationServer.set_locale("en")
    assert_eq(
        TranslationServer.translate(&"ui.app.title"),
        &"Steam Logistics",
        "тестовая английская локаль должна подключаться без изменения кода"
    )
    TranslationServer.set_locale("ru")
    return finish()


func _assert_catalog_complete(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    assert_true(file != null, "CSV-каталог должен открываться")
    if file == null:
        return

    var header := file.get_csv_line()
    assert_true(header.size() >= 3, "CSV должен содержать keys, ru и en")
    assert_eq(header[0], "keys", "первый столбец должен называться keys")
    assert_eq(header[1], "ru", "второй столбец должен быть русским")

    var seen_keys: Dictionary = {}
    while not file.eof_reached():
        var row := file.get_csv_line()
        if row.is_empty() or (row.size() == 1 and row[0].is_empty()):
            continue
        assert_true(row.size() >= 3, "каждая строка должна иметь три столбца")
        if row.size() < 3:
            continue
        assert_true(not row[0].is_empty(), "ключ локализации не может быть пустым")
        assert_true(not seen_keys.has(row[0]), "ключ локализации не должен повторяться: %s" % row[0])
        assert_true(not row[1].is_empty(), "русское значение не может быть пустым: %s" % row[0])
        seen_keys[row[0]] = true
```

- [ ] **Шаг 2: запустить тест и убедиться, что текущая конфигурация проходит**

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/run_tests.gd
```

Ожидание: `TESTS PASSED: 8 suites`.

- [ ] **Шаг 3: создать единый проверочный скрипт**

Создать `scripts/check_project.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd
"$GODOT_BIN" --headless --path . --quit-after 2

echo "Проверка проекта завершена успешно."
```

Сделать его исполняемым:

```bash
chmod +x scripts/check_project.sh
```

- [ ] **Шаг 4: создать русскоязычный README этапа 1**

Создать `README.md`:

````markdown
# Паровая логистика

Прототип колониально-индустриальной стимпанк-игры на гексах. Текущий этап содержит техническую основу: карту 18×18, русскую локализацию, выбор клетки, перемещение и масштабирование камеры, а также headless-тесты.

## Требования

- macOS;
- Godot 4.6.2 в `/Applications/Godot.app`.

## Проверка

```bash
./scripts/check_project.sh
```

## Запуск редактора

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --editor --path .
```

## Управление

- левая кнопка мыши — выбрать гекс;
- средняя кнопка мыши и перетаскивание — переместить камеру;
- колёсико мыши — изменить масштаб.

## Язык

Исходный язык игры и документации — русский. Пользовательские строки находятся в `localization/game.csv`; второй язык добавляется новым столбцом без изменения игрового кода.

## Документы

- проектная спецификация: `docs/superpowers/specs/2026-07-10-steampunk-logistics-prototype-design.md`;
- план этапа 1: `docs/superpowers/plans/2026-07-10-etap-1-osnova-godot.md`.
````

- [ ] **Шаг 5: выполнить полную автоматическую проверку**

```bash
./scripts/check_project.sh
```

Ожидание:

```text
TESTS PASSED: 8 suites
Проверка проекта завершена успешно.
```

- [ ] **Шаг 6: выполнить визуальную проверку в установленном Godot**

Открыть проект через GUI-канал или командой:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --editor --path .
```

Проверить:

1. Окно показывает русский заголовок и строку «Выберите гекс».
2. На карте видны 324 шестиугольника без разрывов.
3. Левая кнопка выделяет клетку янтарным контуром и показывает её `q/r`.
4. Средняя кнопка перемещает камеру.
5. Колёсико меняет масштаб, но не выходит за `0.5..2.0`.
6. Русские буквы отображаются без квадратов и обрезания.

- [ ] **Шаг 7: закоммитить проверку и документацию**

```bash
git add README.md scripts/check_project.sh tests/integration/test_project_configuration.gd
git commit -m "test: добавить полную проверку этапа 1"
```

- [ ] **Шаг 8: отправить этап и зафиксировать gate**

```bash
git push origin main
```

Gate этапа 1 пройден только если:

- `./scripts/check_project.sh` зелёный;
- визуальная проверка выполнена в Godot 4.6.2;
- рабочая директория чистая;
- `origin/main` содержит все семь коммитов реализации;
- не добавлены рабочие, здания или логистические системы из последующих этапов.

## Официальные справочные материалы

- CSV-переводы Godot: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_translations.html
- Интернационализация игр: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
- `TranslationServer` 4.6: https://docs.godotengine.org/en/4.6/classes/class_translationserver.html
- `ThemeDB.fallback_font`: https://docs.godotengine.org/en/stable/classes/class_themedb.html
- рисование `CanvasItem`: https://docs.godotengine.org/en/4.5/classes/class_canvasitem.html
- `Camera2D`: https://docs.godotengine.org/en/stable/classes/class_camera2d.html
