class_name UtilityPortDef
extends Resource

const DIRECTION_INPUT := &"input"
const DIRECTION_OUTPUT := &"output"

@export var direction: StringName = DIRECTION_INPUT
@export var commodity_id: StringName = &"water"


func is_valid() -> bool:
    return (
        direction == DIRECTION_INPUT or direction == DIRECTION_OUTPUT
    ) and not commodity_id.is_empty()
