extends TestCase


func run() -> Array[String]:
    _assert_atomic_delivery()
    _assert_failed_load_preserves_reservations()
    return finish()


func _assert_atomic_delivery() -> void:
    var state := _prepared_state()
    var job := state.get_job(1)
    var worker := state.get_worker(job.worker_id)
    var source := state.get_building(job.source_id)
    var destination := state.get_building(job.destination_id)
    var incoming_before := destination.get_incoming_reserved(job.resource_id)

    worker.action = WorkerState.LOADING
    worker.operation_progress = state.load_ticks - 1
    job.state = DeliveryJob.LOADING
    InventorySystem.new().run(state, 11)
    assert_eq(source.get_amount(job.resource_id), 0, "погрузка забирает одну единицу")
    assert_eq(source.get_outgoing_reserved(job.resource_id), 0, "погрузка снимает outgoing reserve")
    assert_eq(worker.cargo_resource_id, job.resource_id, "груз атомарно переходит worker")
    assert_eq(
        destination.get_incoming_reserved(job.resource_id),
        incoming_before,
        "incoming reserve сохраняется до разгрузки"
    )

    worker.action = WorkerState.UNLOADING
    worker.operation_progress = state.unload_ticks - 1
    job.state = DeliveryJob.UNLOADING
    InventorySystem.new().run(state, 12)
    assert_eq(destination.get_amount(&"wood"), 1, "разгрузка добавляет груз на склад")
    assert_eq(
        destination.get_incoming_reserved(&"wood"),
        incoming_before - 1,
        "разгрузка снимает только reserve завершённого job"
    )
    assert_eq(worker.cargo_resource_id, &"", "после разгрузки worker не несёт груз")
    assert_eq(worker.job_id, 0, "после разгрузки worker освобождается")
    assert_eq(state.get_job(job.id), null, "завершённый job удаляется из активных")
    assert_eq(state.delivered_totals.get(&"wood", 0), 1, "счётчик доставки увеличивается")
    assert_true(InvariantChecker.new().check(state).is_empty(), "после доставки все инварианты соблюдены")


func _assert_failed_load_preserves_reservations() -> void:
    var state := _prepared_state()
    var job := state.get_job(1)
    var worker := state.get_worker(job.worker_id)
    var source := state.get_building(job.source_id)
    var destination := state.get_building(job.destination_id)
    var outgoing_before := source.get_outgoing_reserved(job.resource_id)
    var incoming_before := destination.get_incoming_reserved(job.resource_id)
    source.remove_amount(job.resource_id, 1)
    worker.action = WorkerState.LOADING
    worker.operation_progress = state.load_ticks - 1
    job.state = DeliveryJob.LOADING

    InventorySystem.new().run(state, 11)
    assert_eq(worker.cargo_resource_id, &"", "неудачная погрузка не создаёт cargo")
    assert_eq(source.get_outgoing_reserved(job.resource_id), outgoing_before, "outgoing reserve не теряется")
    assert_eq(destination.get_incoming_reserved(job.resource_id), incoming_before, "incoming reserve не теряется")
    assert_eq(state.get_job(job.id), job, "неудачная погрузка сохраняет job")
    assert_eq(worker.wait_reason, &"missing_cargo", "неудачная погрузка имеет явную причину")


func _prepared_state() -> SimulationState:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    WorkforceSystem.new().run(state, 10)
    JobSystem.new().run(state, 10)
    AssignmentSystem.new().run(state, Pathfinder.new(), 10)
    return state
