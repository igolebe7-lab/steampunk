extends TestCase


func run() -> Array[String]:
    var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(instance)
    _assert_stage5_nodes(instance)
    _assert_pipe_intent(instance)
    _assert_result_and_effects(instance)
    instance.free()
    return finish()


func _assert_stage5_nodes(instance: Node) -> void:
    for path in [
        "UI/BottomBar/Margin/Tools/PipeBuild",
        "UI/BottomBar/Margin/Tools/PipeRemove",
        "UI/LeftPanel/Margin/Layers/Utilities",
        "UI/LeftPanel/Margin/Layers/Phase",
        "UI/ResultPanel",
        "World/IndustrialEffectsView",
    ]:
        assert_true(instance.has_node(path), "узел этапа 5 существует: %s" % path)
    assert_true(instance.get_runner().state.scenario_progress.enabled, "главная сцена запускает полный сценарий")


func _assert_pipe_intent(instance: Node) -> void:
    var runner: SimulationRunner = instance.get_runner()
    var main := runner.state.get_building(runner.state.main_warehouse_id)
    main.inventories[&"iron"] = 10
    runner.state.generated_totals[&"iron"] = 10
    var path: Array[HexCoord] = [
        HexCoord.new(13, 8),
        HexCoord.new(12, 9),
        HexCoord.new(11, 9),
        HexCoord.new(10, 9),
        HexCoord.new(10, 8),
    ]
    var code := (instance.get_hud_controller() as HUDController).submit_intent({
        &"code": &"pipe_build",
        &"cells": path,
    })
    assert_eq(code, &"accepted", "HUD проводит трубу через command runner")
    assert_eq(runner.state.utility_network.segments.size(), 5, "пять сегментов применены атомарно")


func _assert_result_and_effects(instance: Node) -> void:
    var effects := instance.get_node("World/IndustrialEffectsView")
    assert_eq(effects.get_signal_count(), 4, "четыре процедурных звуковых сигнала созданы")
    assert_true(effects.get_signal_data_size(&"hammer") > 0, "звук молота содержит PCM-данные")

    var state: SimulationState = instance.get_runner().state
    state.scenario_progress.phase = ScenarioProgressState.COMPLETED
    state.scenario_progress.hammer_strikes = 1
    state.scenario_progress.completed_tick = 1200
    state.scenario_progress.final_metrics = {
        &"active_ticks": 300,
        &"manual_water": 2,
        &"pipe_water": 12,
        &"completed_jobs": 20,
    }
    instance.get_result_panel_controller().refresh(state)
    var panel := instance.get_node("UI/ResultPanel") as Control
    assert_true(panel.visible, "итоговая панель показывается после первого удара")
    assert_true(
        not (instance.get_node("UI/ResultPanel/Margin/VBox/Metrics") as RichTextLabel).text.contains("ui.result"),
        "итоговая панель показывает переведённый текст"
    )
