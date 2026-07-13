extends SceneTree

const TEST_ROOT := "res://tests"


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var failures: Array[String] = []
    var suites := _discover_suites(TEST_ROOT)

    for suite_path in suites:
        var suite_script := load(suite_path) as Script
        if suite_script == null:
            failures.append("%s: файл теста не загружен" % suite_path)
            continue

        var suite: Variant = suite_script.new()
        if not suite.has_method("run"):
            failures.append("%s: отсутствует метод run()" % suite_path)
            continue

        var suite_failures: Array = suite.call("run")
        for failure in suite_failures:
            failures.append("%s: %s" % [suite_path, str(failure)])

    if failures.is_empty():
        print("TESTS PASSED: %d suites" % suites.size())
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    print("TESTS FAILED: %d failures" % failures.size())
    quit(1)


func _discover_suites(root_path: String) -> Array[String]:
    var result: Array[String] = []

    for file_name in DirAccess.get_files_at(root_path):
        if (
            file_name != "test_case.gd"
            and file_name.begins_with("test_")
            and file_name.ends_with(".gd")
        ):
            result.append(root_path.path_join(file_name))

    for directory_name in DirAccess.get_directories_at(root_path):
        if not directory_name.begins_with("."):
            result.append_array(_discover_suites(root_path.path_join(directory_name)))

    result.sort()
    return result
