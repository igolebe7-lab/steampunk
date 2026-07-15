extends TestCase


func run() -> Array[String]:
    _assert_speed_tick_counts()
    _assert_pause_and_paused_flush()
    _assert_speed_does_not_change_tick_logic()
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
    var runner := _runner()
    var controller := SimulationController.new()
    controller.configure(runner)
    controller.set_paused(true)
    controller.advance_frame(1.0)
    assert_eq(runner.state.tick, 0, "pause прекращает обычные simulation ticks")

    runner.enqueue(SimulationCommand.set_building_priority(1, 1, 1, 4))
    var paused_hash := controller.flush_commands()
    assert_eq(runner.state.tick, 0, "controller flush на паузе не продвигает tick")
    assert_eq(runner.state.revision, 1, "controller использует runner command transaction")
    assert_eq(paused_hash.length(), 64, "controller возвращает hash paused transaction")
    controller.free()


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


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
