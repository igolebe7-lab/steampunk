class_name IndustrialEffectsView
extends Node2D

var _layout: HexLayout
var _flash_position := Vector2.ZERO
var _flash_ticks: int = 0


func configure(layout: HexLayout) -> void:
    _layout = layout


func capture_tick(state: SimulationState) -> void:
    _flash_ticks = maxi(_flash_ticks - 1, 0)
    for event: SimulationEvent in state.events:
        if event.code == &"hammer_struck":
            var building := state.get_building(event.entity_id)
            if building != null and _layout != null:
                _flash_position = _layout.coord_to_pixel(building.coord)
                _flash_ticks = 8
    queue_redraw()


func _draw() -> void:
    if _flash_ticks > 0:
        draw_circle(_flash_position, 10.0 + _flash_ticks * 2.0, Color(1.0, 0.72, 0.25, 0.15 + _flash_ticks * 0.05))
