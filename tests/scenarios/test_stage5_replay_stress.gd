extends TestCase

const STRESS_TICKS := 4000
const HASH_CHECKPOINT_INTERVAL := 10


func run() -> Array[String]:
    var first := Stage5TestFactory.full_runner(false)
    var second := Stage5TestFactory.full_runner(false)
    var hasher := StateHasher.new()
    var pipe_built := false
    var pipe_removed := false
    var pipe_rebuilt := false
    for _index in STRESS_TICKS:
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
        first.step()
        second.step()
        if first.state.tick % HASH_CHECKPOINT_INTERVAL == 0:
            assert_eq(
                hasher.hash_state(first.state),
                hasher.hash_state(second.state),
                "полный replay детерминирован на checkpoint %d" % first.state.tick
            )
    assert_true(pipe_built, "stress trace включает строительство трубы")
    assert_true(pipe_removed, "stress trace включает демонтаж трубы")
    assert_true(pipe_rebuilt, "stress trace включает повторное строительство трубы")
    assert_eq(first.state.utility_network.segments.size(), 4, "повторно построенная труба остаётся в мире")
    assert_eq(first.state.scenario_progress.phase, ScenarioProgressState.COMPLETED, "stress trace завершает сценарий")
    assert_eq(first.state.tick, STRESS_TICKS, "stress trace проходит всё заданное окно")
    assert_true(InvariantChecker.new().check(first.state).is_empty(), "итог stress сохраняет инварианты")
    return finish()
