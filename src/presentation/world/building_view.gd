class_name BuildingView
extends Node2D

const SOURCE_COLOR := Color("#497457")
const DEPOT_COLOR := Color("#9a7140")
const METAL_COLOR := Color("#29353a")
const OUTLINE_COLOR := Color("#d2b077")

var building_id: int
var _is_source := false
var _label: Label


func _ready() -> void:
    _label = Label.new()
    _label.position = Vector2(-70.0, 24.0)
    _label.size = Vector2(140.0, 22.0)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_color_override("font_color", Color("#e7dfcd"))
    _label.add_theme_color_override("font_outline_color", Color("#172024"))
    _label.add_theme_constant_override("outline_size", 3)
    _label.add_theme_font_size_override("font_size", 12)
    add_child(_label)


func configure(building: BuildingState, definition: BuildingDef) -> void:
    building_id = building.id
    _is_source = definition.is_source()
    _label.text = tr(definition.display_name_key)
    queue_redraw()


func _draw() -> void:
    var body_color := SOURCE_COLOR if _is_source else DEPOT_COLOR
    draw_rect(Rect2(-21.0, -14.0, 42.0, 28.0), body_color, true)
    draw_rect(Rect2(-21.0, -14.0, 42.0, 28.0), OUTLINE_COLOR, false, 2.0)
    draw_colored_polygon(
        PackedVector2Array([Vector2(-25.0, -14.0), Vector2.ZERO + Vector2(0.0, -26.0), Vector2(25.0, -14.0)]),
        METAL_COLOR
    )
    if _is_source:
        draw_rect(Rect2(10.0, -28.0, 7.0, 16.0), METAL_COLOR, true)
        draw_circle(Vector2(13.5, -31.0), 5.0, Color("#657278"))
        draw_circle(Vector2(-10.0, 2.0), 6.0, Color("#8caf69"))
    else:
        draw_rect(Rect2(-13.0, -4.0, 26.0, 18.0), METAL_COLOR, true)
        draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), OUTLINE_COLOR, 2.0)
