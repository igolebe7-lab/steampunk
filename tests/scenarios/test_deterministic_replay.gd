extends TestCase

const FOUNDATION_TRACE := [
    "ed83f56d94886ff4e64cb07b30dd348173a94387f9b78fc0fba0bcc49b1d98d3",
    "3e0e1584cefc672c6961bf458b3d69d9e8fe38c084a110f81d4c65156fb9bcf7",
    "ea47ae2f14175e7442107c0e708df61ac3b70323a869aa6fe75f70e3c2bbfa49",
    "4c7347e98dd2d9f020d7286ceb83d3d5166f55e021f4559e3e6b26d6b5c88165",
    "4ad51eb14707fc133f1d350eb6753270b6ea6bcb4c85a4e51b53720a311556c3",
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
