extends TestCase

const RECIPE_PATH := "res://src/simulation/definitions/recipe_def.gd"
const UTILITY_PORT_PATH := "res://src/simulation/definitions/utility_port_def.gd"
const PRODUCTION_STATE_PATH := "res://src/simulation/model/production_state.gd"


func run() -> Array[String]:
    assert_true(ResourceLoader.exists(RECIPE_PATH), "определение рецепта существует")
    assert_true(ResourceLoader.exists(UTILITY_PORT_PATH), "определение коммунального порта существует")
    assert_true(ResourceLoader.exists(PRODUCTION_STATE_PATH), "состояние производства существует")
    if not ResourceLoader.exists(RECIPE_PATH):
        return finish()

    var recipe_script := load(RECIPE_PATH) as Script
    var recipe: Variant = recipe_script.new()
    recipe.id = &"boiler_heat_cycle"
    recipe.input_resource_ids.assign([&"coal", &"water"])
    recipe.input_amounts.assign([1, 2])
    recipe.duration_ticks = 120
    recipe.display_name_key = &"recipe.boiler.name"
    recipe.description_key = &"recipe.boiler.description"
    assert_eq(recipe.input_amount(&"water"), 2, "рецепт хранит расход воды")
    assert_eq(recipe.input_amount(&"wood"), 0, "неизвестный вход возвращает ноль")

    var catalog := DefinitionCatalog.new()
    catalog.resources = [_resource(&"coal"), _resource(&"water")]
    catalog.recipes = [recipe]
    assert_true(catalog.validate().is_empty(), "валидный рецепт принимается")
    assert_eq(catalog.get_recipe(&"boiler_heat_cycle"), recipe, "рецепт доступен по id")

    var duplicate := DefinitionCatalog.new()
    duplicate.resources = catalog.resources
    duplicate.recipes = [recipe, recipe]
    assert_true(duplicate.validate().has(&"duplicate_recipe_id"), "повтор id рецепта отклоняется")

    var state_script := load(PRODUCTION_STATE_PATH) as Script
    var production: Variant = state_script.new(7, &"boiler_heat_cycle")
    assert_eq(production.building_id, 7, "производство связано со зданием")
    assert_eq(production.status, &"locked", "новое производство заблокировано")
    return finish()


func _resource(id: StringName) -> ResourceDef:
    var definition := ResourceDef.new()
    definition.id = id
    definition.display_name_key = StringName("resource.%s.name" % id)
    return definition
