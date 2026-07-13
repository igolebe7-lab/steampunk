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

    var target := HexCoord.new(3, 4)
    assert_true(view.select_at_local_position(layout.coord_to_pixel(target)), "центр существующего гекса должен выбираться")
    assert_true(view.get_selected_coord().equals(target), "выбранная координата должна совпасть с целью")
    assert_true(not view.select_at_local_position(layout.coord_to_pixel(HexCoord.new(30, 30))), "позиция вне карты должна отклоняться")
    view.free()
    return finish()
