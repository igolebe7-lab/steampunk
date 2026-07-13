extends TestCase


func run() -> Array[String]:
    assert_eq(SimulationRunner.DEFAULT_TICKS_PER_SECOND, 10, "симуляция должна использовать конфигурацию 10 Гц")

    var first := _create_runner()
    var second := _create_runner()
    var changed := _create_runner()
    assert_true(first != null and second != null and changed != null, "сценарий должен создавать три раннера")
    if first == null or second == null or changed == null:
        return finish()

    _enqueue_trace(first, 1)
    _enqueue_trace(second, 1)
    _enqueue_trace(changed, 4)

    var first_hashes := first.run_ticks(5)
    var second_hashes := second.run_ticks(5)
    var changed_hashes := changed.run_ticks(5)
    assert_eq(first_hashes, second_hashes, "одинаковая трасса должна совпадать после каждого тика")
    assert_eq(first_hashes.size(), 5, "раннер должен вернуть хэш каждого завершённого тика")
    assert_true(
        first_hashes[-1] != changed_hashes[-1],
        "изменённая команда должна менять итоговый хэш"
    )
    assert_eq(first.state.tick, 5, "после пяти шагов состояние должно завершить пятый тик")
    return finish()


func _create_runner() -> SimulationRunner:
    var scenario := load("res://data/scenarios/foundation.tres") as ScenarioDef
    var result := ScenarioLoader.new().load_scenario(scenario)
    if not result.is_success():
        return null
    return SimulationRunner.new(result.state)


func _enqueue_trace(runner: SimulationRunner, first_priority: int) -> void:
    runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, first_priority))
    runner.enqueue(SimulationCommand.set_building_priority(2, 20, 2, 3))
    runner.enqueue(SimulationCommand.set_building_priority(4, 30, 3, 0))
