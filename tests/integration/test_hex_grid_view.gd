extends TestCase


func run() -> Array[String]:
    var script_path := "res://src/presentation/world/hex_grid_view.gd"
    assert_true(ResourceLoader.exists(script_path), "скрипт HexGridView должен существовать")
    if not ResourceLoader.exists(script_path):
        return finish()

    var view: Variant = load(script_path).new()
    var map_state := HexMapState.new(18, 18)
    var layout := HexLayout.new(32.0, Vector2.ZERO)
    view.configure(map_state, layout)

    assert_true(
        view.get_world_rect().size.y < 1100.0,
        "staggered-карта 18×18 не должна вытягиваться в наклонный аксиальный параллелограмм"
    )

    var target := HexCoord.new(3, 4)
    var emitted_coords: Array[HexCoord] = []
    view.hex_selected.connect(func(coord: HexCoord) -> void: emitted_coords.append(coord))
    assert_true(view.select_at_local_position(layout.coord_to_pixel(target)), "центр существующего гекса должен выбираться")
    assert_true(view.get_selected_coord().equals(target), "выбранная координата должна совпасть с целью")
    assert_eq(emitted_coords.size(), 1, "успешный выбор должен отправить один сигнал")
    assert_true(emitted_coords[0].equals(target), "сигнал должен содержать выбранную координату")
    assert_true(not view.select_at_local_position(layout.coord_to_pixel(HexCoord.new(30, 30))), "позиция вне карты должна отклоняться")
    view.free()
    return finish()
