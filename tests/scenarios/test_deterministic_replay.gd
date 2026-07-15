extends TestCase

const FOUNDATION_TRACE := [
    "73685f6fcff8e2f08f59df102cc531df079daf0ffab6cae93ae38fc448f829fe",
    "d058e82a80453d442ae45ebc0c4df69644c3422c451cc14e9c1257f39854b334",
    "151510f5fa9a68b6c8465dbf65bea780574b089dcbde9d6fbd0a7dda61cc8a09",
    "21c6107e7d96309dadcdacee1a594e7ba82eabb859d62e9e23ba114744fcdf36",
    "b7546f249c29f69843303e1ee0055b9f2375b246e63e0e299f4b69f0b13d9738",
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
