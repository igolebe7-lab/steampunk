extends TestCase


func run() -> Array[String]:
    _assert_flush_applies_without_advancing_time()
    _assert_paused_command_replay_is_deterministic()
    return finish()


func _assert_flush_applies_without_advancing_time() -> void:
    var runner := _runner()
    assert_true(runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, 4)).accepted, "due command принимается")
    assert_true(runner.enqueue(SimulationCommand.set_building_priority(2, 20, 2, 3)).accepted, "future command принимается")

    var paused_hash := runner.flush_commands()

    assert_eq(runner.state.tick, 0, "flush_commands не продвигает simulation tick")
    assert_eq(runner.state.revision, 1, "command transaction увеличивает revision один раз")
    assert_eq(runner.state.get_building(1).priority, 4, "due command применяется на паузе")
    assert_true(runner.state.get_building(2).priority != 3, "future command остаётся в очереди")
    assert_eq(paused_hash.length(), 64, "flush_commands возвращает deterministic hash")
    assert_true(InvariantChecker.new().check(runner.state).is_empty(), "flush_commands проверяет корректное состояние")

    runner.step()
    assert_eq(runner.state.tick, 1, "следующий обычный step продвигает ровно один tick")
    assert_eq(runner.state.revision, 1, "step без due commands не меняет revision")
    runner.flush_commands()
    assert_eq(runner.state.tick, 1, "вторая paused transaction сохраняет текущий tick")
    assert_eq(runner.state.revision, 2, "следующий due batch создаёт новую revision")
    assert_eq(runner.state.get_building(2).priority, 3, "команда следующего tick применяется после первого step")


func _assert_paused_command_replay_is_deterministic() -> void:
    var first := _runner()
    var second := _runner()
    for runner: SimulationRunner in [first, second]:
        runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, 4))
        runner.enqueue(SimulationCommand.set_building_priority(1, 20, 2, 1))
    var first_hash := first.flush_commands()
    var second_hash := second.flush_commands()
    assert_eq(first_hash, second_hash, "одинаковые paused commands дают одинаковый v=4 hash")
    assert_true(StateHasher.new().canonicalize(first.state).begins_with("v=4|"), "paused hash сохраняет формат v=4")


func _runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    return SimulationRunner.new(ScenarioLoader.new().load_scenario(scenario).state)
