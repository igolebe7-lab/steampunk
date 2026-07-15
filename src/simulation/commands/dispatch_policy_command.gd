class_name DispatchPolicyCommand
extends SimulationCommand

var building_id: int
var allows_direct_delivery_to_main: bool


func _init(
    p_target_tick: int,
    p_sequence: int,
    p_building_id: int,
    p_allows_direct_delivery_to_main: bool
) -> void:
    super(SimulationCommand.SET_DISPATCH_POLICY, p_target_tick, p_sequence)
    building_id = p_building_id
    allows_direct_delivery_to_main = p_allows_direct_delivery_to_main


func snapshot() -> SimulationCommand:
    return DispatchPolicyCommand.new(
        target_tick,
        sequence,
        building_id,
        allows_direct_delivery_to_main
    )
