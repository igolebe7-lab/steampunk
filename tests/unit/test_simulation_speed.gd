extends TestCase


func run() -> Array[String]:
    _assert_speed_tick_counts()
    _assert_pause_and_paused_flush()
    _assert_speed_does_not_change_tick_logic()
    _assert_runtime_mode_skips_debug_hash()
    return finish()


func _assert_speed_tick_counts() -> void:
    for speed in [1, 2, 4]:
        var runner := _runner()
        var controller := SimulationController.new()
        controller.configure(runner)
        assert_true(controller.set_speed_multiplier(speed), "поддерживается скорость x%d" % speed)
        controller.advance_frame(0.1)
        assert_eq(runner.state.tick, speed, "0.1 секунды даёт x%d fixed ticks" % speed)
        controller.free()


func _assert_pause_and_paused_flush() -> void:
    var original_low_processor_mode := OS.low_processor_usage_mode
    var original_max_fps := Engine.max_fps
    OS.low_processor_usage_mode = false
    Engine.max_fps = 30
    var runner := _runner()
    var controller := SimulationController.new()
    controller.configure(runner)
    var paused_interpolation_emissions: Array[int] = [0]
    controller.interpolation_changed.connect(func(_alpha: float) -> void:
        paused_interpolation_emissions[0] += 1
    )
    controller.set_paused(true)
    assert_true(OS.low_processor_usage_mode, "пауза переводит Godot в щадящий процессорный режим")
    assert_eq(Engine.max_fps, 10, "пауза ограничивает статичный Canvas десятью кадрами")
    controller.advance_frame(1.0)
    assert_eq(runner.state.tick, 0, "pause прекращает обычные simulation ticks")
    assert_eq(paused_interpolation_emissions[0], 0, "пауза не будит Canvas сигналом неизменной интерполяции")

    runner.enqueue(SimulationCommand.set_building_priority(1, 1, 1, 4))
    var paused_hash := controller.flush_commands()
    assert_eq(runner.state.tick, 0, "controller flush на паузе не продвигает tick")
    assert_eq(runner.state.revision, 1, "controller использует runner command transaction")
    assert_eq(paused_hash.length(), 64, "controller возвращает hash paused transaction")
    controller.set_paused(false)
    assert_true(not OS.low_processor_usage_mode, "продолжение возвращает обычную частоту обработки")
    assert_eq(Engine.max_fps, 30, "продолжение восстанавливает проектный лимит кадров")
    controller.free()
    OS.low_processor_usage_mode = original_low_processor_mode
    Engine.max_fps = original_max_fps


func _assert_speed_does_not_change_tick_logic() -> void:
    var normal_runner := _runner()
    var fast_runner := _runner()
    var normal := SimulationController.new()
    var fast := SimulationController.new()
    normal.configure(normal_runner)
    fast.configure(fast_runner)
    fast.set_speed_multiplier(4)
    normal.advance_frame(0.1)
    fast.advance_frame(0.025)
    assert_eq(normal_runner.state.tick, 1, "normal выполняет один fixed tick")
    assert_eq(fast_runner.state.tick, 1, "ускорение меняет только real-time accumulation")
    assert_eq(
        StateHasher.new().hash_state(normal_runner.state),
        StateHasher.new().hash_state(fast_runner.state),
        "скорость не изменяет логику одного fixed tick"
    )
    normal.free()
    fast.free()


func _assert_runtime_mode_skips_debug_hash() -> void:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    var runner := SimulationRunner.new(state, false)
    var hash := runner.step()
    assert_eq(runner.state.tick, 1, "runtime runner сохраняет fixed-tick поведение")
    assert_eq(hash, "", "runtime runner не строит отладочный SHA-256 на каждом тике")


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
