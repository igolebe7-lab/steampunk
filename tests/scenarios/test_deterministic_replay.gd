extends TestCase

const FOUNDATION_TRACE := [
    "91ea1b2907b3232166389777aedde5e50ad268bb62965ec05f2b2841eb94eb62",
    "f1b240cb9cd000a4cad5e0499063419038f37184e98ac65b70dc58f879aca4f9",
    "e69996e9e53ee646977bbd20f681a21f9be04ec87b5045d1db61018ff41e18d2",
    "91159d2fd2ae30996bccad70916625c9d7b901abbce6ef00b76e358f80d08814",
    "16bac767c2ba59f293c196a3eaff7c69685420536f7e227b9c89353f78e1fd53",
]


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
    assert_eq(first_hashes, FOUNDATION_TRACE, "replay должен совпадать с межпроцессной golden-трассой")
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
    assert_true(
        runner.enqueue(SimulationCommand.set_building_priority(1, 10, 1, first_priority)).accepted,
        "команда первого тика должна попасть в replay"
    )
    assert_true(
        runner.enqueue(SimulationCommand.set_building_priority(2, 20, 2, 3)).accepted,
        "команда второго тика должна попасть в replay"
    )
    assert_true(
        runner.enqueue(SimulationCommand.set_building_priority(4, 30, 3, 0)).accepted,
        "команда четвёртого тика должна попасть в replay"
    )
