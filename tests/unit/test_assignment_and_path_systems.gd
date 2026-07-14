extends TestCase


func run() -> Array[String]:
    var scenario := load("res://data/scenarios/physical_logistics.tres") as ScenarioDef
    var state := ScenarioLoader.new().load_scenario(scenario).state
    for tick in range(1, 11):
        SourceSystem.new().run(state, tick)
    JobSystem.new().run(state, 10)

    var finder := Pathfinder.new()
    AssignmentSystem.new().run(state, finder, 10)
    PathSystem.new().run(state, finder, 10)

    var assigned := 0
    for worker: WorkerState in state.workers.values():
        if worker.job_id > 0:
            assigned += 1
            assert_true(not worker.route.is_empty(), "назначенный worker получает route")
            assert_eq(state.get_job(worker.job_id).worker_id, worker.id, "worker/job связь симметрична")
    assert_eq(assigned, 2, "два задания получают двух workers")
    return finish()
