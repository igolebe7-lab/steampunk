class_name IndustrialEffectsView
extends Node2D

var _layout: HexLayout
var _flash_position := Vector2.ZERO
var _flash_ticks: int = 0
var _streams: Dictionary = {}
var _players: Dictionary = {}


func configure(layout: HexLayout) -> void:
    _layout = layout
    if _streams.is_empty():
        _create_signals()


func capture_tick(state: SimulationState) -> void:
    _flash_ticks = maxi(_flash_ticks - 1, 0)
    for event: SimulationEvent in state.events:
        if event.code == &"hammer_struck":
            _play(&"hammer")
            var building := state.get_building(event.entity_id)
            if building != null and _layout != null:
                _flash_position = _layout.coord_to_pixel(building.coord)
                _flash_ticks = 8
        elif event.code == &"pipe_built":
            _play(&"pipe")
        elif event.code == &"pipe_water_delivered":
            _play(&"pump")
        elif event.code == &"production_completed" and event.reason == &"boiler_heat":
            _play(&"steam")
    queue_redraw()


func _draw() -> void:
    if _flash_ticks > 0:
        draw_circle(_flash_position, 10.0 + _flash_ticks * 2.0, Color(1.0, 0.72, 0.25, 0.15 + _flash_ticks * 0.05))


func get_signal_count() -> int:
    return _streams.size()


func get_signal_data_size(code: StringName) -> int:
    var stream := _streams.get(code) as AudioStreamWAV
    return 0 if stream == null else stream.data.size()


func _create_signals() -> void:
    for code: StringName in [&"pipe", &"pump", &"steam", &"hammer"]:
        var stream := AudioStreamWAV.new()
        stream.format = AudioStreamWAV.FORMAT_8_BITS
        stream.mix_rate = 22050
        stream.stereo = false
        stream.data = _pcm(code, 2205)
        _streams[code] = stream
        var player := AudioStreamPlayer.new()
        player.stream = stream
        player.volume_db = -16.0
        add_child(player)
        _players[code] = player


func _pcm(code: StringName, count: int) -> PackedByteArray:
    var data := PackedByteArray()
    data.resize(count)
    for index in count:
        var time := float(index) / 22050.0
        var envelope := exp(-time * (28.0 if code in [&"pipe", &"hammer"] else 8.0))
        var value := 0.0
        match code:
            &"pipe": value = sin(TAU * 920.0 * time) * envelope
            &"pump": value = sin(TAU * 58.0 * time) * 0.65 + sin(TAU * 116.0 * time) * 0.2
            &"steam": value = (float((index * 37 + 17) % 101) / 50.0 - 1.0) * envelope
            &"hammer": value = (sin(TAU * 86.0 * time) + sin(TAU * 172.0 * time) * 0.45) * envelope
        data[index] = clampi(roundi(value * 92.0) + 128, 0, 255)
    return data


func _play(code: StringName) -> void:
    var player := _players.get(code) as AudioStreamPlayer
    if player != null:
        player.play()
