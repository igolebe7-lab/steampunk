extends TestCase

const IRON := &"iron"


func run() -> Array[String]:
    _assert_valid_build_charges_once()
    _assert_invalid_paths_are_atomic()
    _assert_remove_is_atomic_and_has_no_refund()
    return finish()


func _assert_valid_build_charges_once() -> void:
    var state := Stage5TestFactory.pipe_state(10)
    var path := Stage5TestFactory.pipe_path()
    var result := CommandSystem.new().apply(state, PipeCommand.build(1, 1, path))
    assert_true(result.accepted, "связный путь от насосной до котла строится")
    assert_eq(state.utility_network.segments.size(), 3, "созданы три сегмента")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(IRON), 8, "три сегмента стоят два железа")
    assert_eq(state.consumed_totals.get(IRON, 0), 2, "стоимость учтена как потребление")
    assert_eq(state.utility_network.topology_revision, 1, "топология изменена один раз")


func _assert_invalid_paths_are_atomic() -> void:
    var insufficient := Stage5TestFactory.pipe_state(1)
    _assert_rejected_unchanged(insufficient, Stage5TestFactory.pipe_path(), &"insufficient_iron")

    var disconnected := Stage5TestFactory.pipe_state(10)
    _assert_rejected_unchanged(
        disconnected,
        [HexCoord.new(2, 0), HexCoord.new(4, 0)],
        &"invalid_pipe_path"
    )

    var occupied := Stage5TestFactory.pipe_state(10)
    _assert_rejected_unchanged(
        occupied,
        [HexCoord.new(2, 0), HexCoord.new(1, 0)],
        &"pipe_cell_occupied"
    )


func _assert_remove_is_atomic_and_has_no_refund() -> void:
    var state := Stage5TestFactory.pipe_state(10)
    var path := Stage5TestFactory.pipe_path()
    assert_true(CommandSystem.new().apply(state, PipeCommand.build(1, 1, path)).accepted, "подготовка сети")
    var iron_after_build := state.get_building(state.main_warehouse_id).get_amount(IRON)
    var bad_remove := CommandSystem.new().apply(
        state,
        PipeCommand.remove(2, 2, [path[0], HexCoord.new(3, -1)])
    )
    assert_eq(bad_remove.code, &"pipe_segment_missing", "отсутствующий сегмент отклоняет разбор")
    assert_eq(state.utility_network.segments.size(), 3, "неполного разбора нет")

    var removed := CommandSystem.new().apply(state, PipeCommand.remove(3, 3, path))
    assert_true(removed.accepted, "существующий путь разбирается")
    assert_true(state.utility_network.segments.is_empty(), "все выбранные сегменты удалены")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(IRON), iron_after_build, "разбор не возвращает железо")
    assert_eq(state.utility_network.topology_revision, 2, "разбор меняет topology revision")


func _assert_rejected_unchanged(
    state: SimulationState,
    path: Array[HexCoord],
    expected_code: StringName
) -> void:
    var initial_iron := state.get_building(state.main_warehouse_id).get_amount(IRON)
    var result := CommandSystem.new().apply(state, PipeCommand.build(1, 1, path))
    assert_eq(result.code, expected_code, "ошибка пути имеет стабильный код")
    assert_true(state.utility_network.segments.is_empty(), "ошибка не оставляет сегменты")
    assert_eq(state.get_building(state.main_warehouse_id).get_amount(IRON), initial_iron, "ошибка не списывает железо")
    assert_eq(state.utility_network.topology_revision, 0, "ошибка не меняет topology revision")
