extends TestCase

const FOUNDATION_TRACE := [
    "12811c2dd95ac5f456a2dd5422634a74a9f7a056d4130b6a6c37e3224f2b1802",
    "188fba465c80ff76fb193924cc0372706f9f88fa754b99baa551e9690b9920e3",
    "670e4c729a826e4ecead0469d3f5db7631a615daeb9d7217a3e5073712665976",
    "2c9f29717796e9cddf7af5ba0de71ded7e92ad78eb6ee66e9e15cfddc67c2b62",
    "ef938bc4870ed2447c7d624b441d1ff50ade4fe5290f56a7b7f679483fb02b6d",
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
