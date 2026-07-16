extends TestCase


func run() -> Array[String]:
    assert_true(ResourceLoader.exists("res://src/presentation/world/utility_network_view.gd"), "представление труб существует")
    if not ResourceLoader.exists("res://src/presentation/world/utility_network_view.gd"):
        return finish()
    var state := Stage5TestFactory.connected_pipe_state()
    var view := UtilityNetworkView.new()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(view)
    view.configure(state, HexLayout.new(32.0))
    assert_eq(view.get_segment_visual_count(), 3, "представление кэширует сегменты")
    var rebuilds := view.get_rebuild_count()
    view.capture_tick(state)
    assert_eq(view.get_rebuild_count(), rebuilds, "неизменная топология не пересобирает линии")
    state.utility_network.topology_revision += 1
    view.capture_tick(state)
    assert_eq(view.get_rebuild_count(), rebuilds + 1, "новая ревизия пересобирает линии один раз")
    assert_true(view.hit_test_segment(HexLayout.new(32.0).coord_to_pixel(HexCoord.new(3, 0))) != null, "сегмент выбирается мышью")
    view.free()
    return finish()
