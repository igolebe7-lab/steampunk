extends TestCase


func run() -> Array[String]:
    var catalog := load("res://data/catalog.tres") as DefinitionCatalog
    assert_true(catalog != null, "каталог определений должен загружаться")
    if catalog == null:
        return finish()

    assert_eq(catalog.validate(), [], "базовый каталог должен быть корректным")
    assert_eq(catalog.resources.size(), 4, "каталог должен содержать четыре ресурса")
    assert_eq(catalog.buildings.size(), 5, "каталог должен содержать пять определений зданий")
    assert_eq(catalog.get_resource(&"wood").display_name_key, &"resource.wood.name", "дерево должно иметь ключ названия")
    assert_eq(catalog.get_building(&"steam_hammer").footprint.size(), 3, "паровой молот должен занимать три гекса")

    var duplicate := DefinitionCatalog.new()
    duplicate.resources = [catalog.resources[0], catalog.resources[0]]
    assert_true(duplicate.validate().has(&"duplicate_resource_id"), "повтор ID ресурса должен отклоняться")

    var invalid_footprint := BuildingDef.new()
    invalid_footprint.id = &"invalid_footprint"
    invalid_footprint.display_name_key = &"building.invalid.name"
    invalid_footprint.footprint = [Vector2i.ZERO, Vector2i.ZERO]
    var invalid_catalog := DefinitionCatalog.new()
    invalid_catalog.buildings = [invalid_footprint]
    assert_true(
        invalid_catalog.validate().has(&"duplicate_footprint_cell"),
        "одна клетка footprint не должна повторяться"
    )
    return finish()
