class_name LinkCommand
extends SimulationCommand

var source_id: int
var destination_id: int
var resource_id: StringName
var link_id: int


func _init(
    p_type: StringName,
    p_target_tick: int,
    p_sequence: int,
    p_source_id: int = 0,
    p_destination_id: int = 0,
    p_resource_id: StringName = &"",
    p_link_id: int = 0
) -> void:
    super(p_type, p_target_tick, p_sequence)
    source_id = p_source_id
    destination_id = p_destination_id
    resource_id = p_resource_id
    link_id = p_link_id


static func create(
    p_target_tick: int,
    p_sequence: int,
    p_source_id: int,
    p_destination_id: int,
    p_resource_id: StringName
) -> LinkCommand:
    return LinkCommand.new(
        SimulationCommand.CREATE_LINK,
        p_target_tick,
        p_sequence,
        p_source_id,
        p_destination_id,
        p_resource_id
    )


static func remove(p_target_tick: int, p_sequence: int, p_link_id: int) -> LinkCommand:
    return LinkCommand.new(
        SimulationCommand.REMOVE_LINK,
        p_target_tick,
        p_sequence,
        0,
        0,
        &"",
        p_link_id
    )


static func reset_automatic(
    p_target_tick: int,
    p_sequence: int,
    p_source_id: int,
    p_resource_id: StringName
) -> LinkCommand:
    return LinkCommand.new(
        SimulationCommand.RESET_AUTOMATIC_LINK,
        p_target_tick,
        p_sequence,
        p_source_id,
        0,
        p_resource_id
    )


func snapshot() -> SimulationCommand:
    return LinkCommand.new(
        type,
        target_tick,
        sequence,
        source_id,
        destination_id,
        resource_id,
        link_id
    )
