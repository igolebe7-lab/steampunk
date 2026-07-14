extends TestCase


func run() -> Array[String]:
    var building := BuildingState.new(1, &"transfer_depot", HexCoord.new(), 2)
    building.inventory_capacity = 2
    assert_true(building.add_amount(&"wood", 2), "первый ресурс заполняет общую ёмкость")
    assert_true(
        not building.add_amount(&"iron", 1),
        "второй ресурс не может превысить общую ёмкость"
    )
    assert_eq(building.get_amount(&"iron"), 0, "отклонённый ресурс не записывается")
    return finish()
