class_name TestCase
extends RefCounted

var _failures: Array[String] = []


func assert_true(value: bool, message: String) -> void:
    if not value:
        _failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        _failures.append(
            "%s; ожидалось=%s, получено=%s" % [message, var_to_str(expected), var_to_str(actual)]
        )


func assert_near(actual: float, expected: float, epsilon: float, message: String) -> void:
    if absf(actual - expected) > epsilon:
        _failures.append(
            "%s; ожидалось≈%f, получено=%f" % [message, expected, actual]
        )


func finish() -> Array[String]:
    return _failures.duplicate()
