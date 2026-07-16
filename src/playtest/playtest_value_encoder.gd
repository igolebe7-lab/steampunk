class_name PlaytestValueEncoder
extends RefCounted


static func encode(value: Variant) -> Variant:
    if value == null:
        return null
    if value is HexCoord:
        var coord := value as HexCoord
        return {"q": coord.q, "r": coord.r}
    match typeof(value):
        TYPE_STRING_NAME:
            return String(value)
        TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
            var items: Array = []
            for item: Variant in value:
                items.append(encode(item))
            return items
        TYPE_DICTIONARY:
            var source := value as Dictionary
            var keys := source.keys()
            keys.sort_custom(
                func(left: Variant, right: Variant) -> bool:
                    return str(left) < str(right)
            )
            var result: Dictionary = {}
            for key: Variant in keys:
                result[str(key)] = encode(source[key])
            return result
        TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
            return value
        _:
            return str(value)
