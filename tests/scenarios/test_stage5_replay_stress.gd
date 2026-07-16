extends TestCase


func run() -> Array[String]:
    var first := Stage5TestFactory.full_runner()
    var second := Stage5TestFactory.full_runner()
    var pipe_built := false
    var pipe_removed := false
    var pipe_rebuilt := false
    for _index in 10000:
        if not pipe_built and Stage5TestFactory.can_build_full_pipe(first.state):
            first.enqueue(PipeCommand.build(first.state.tick + 1, 7001, Stage5TestFactory.full_pipe_path()))
            second.enqueue(PipeCommand.build(second.state.tick + 1, 7001, Stage5TestFactory.full_pipe_path()))
            pipe_built = true
        elif pipe_built and not pipe_removed and first.state.tick >= 3200:
            first.enqueue(PipeCommand.remove(first.state.tick + 1, 7002, Stage5TestFactory.full_pipe_path()))
            second.enqueue(PipeCommand.remove(second.state.tick + 1, 7002, Stage5TestFactory.full_pipe_path()))
            pipe_removed = true
        elif pipe_removed and not pipe_rebuilt and Stage5TestFactory.can_build_full_pipe(first.state):
            first.enqueue(PipeCommand.build(first.state.tick + 1, 7003, Stage5TestFactory.full_pipe_path()))
            second.enqueue(PipeCommand.build(second.state.tick + 1, 7003, Stage5TestFactory.full_pipe_path()))
            pipe_rebuilt = true
        assert_eq(first.step(), second.step(), "каждый тик полного replay детерминирован")
    assert_true(pipe_built, "stress trace включает строительство трубы")
    assert_true(pipe_removed, "stress trace включает демонтаж трубы")
    assert_true(pipe_rebuilt, "stress trace включает повторное строительство трубы")
    assert_eq(first.state.utility_network.segments.size(), 4, "повторно построенная труба остаётся в мире")
    assert_eq(first.state.scenario_progress.phase, ScenarioProgressState.COMPLETED, "stress trace завершает сценарий")
    return finish()
