class_name PlaytestReportWriter
extends RefCounted


func build_json(session: PlaytestSession, analysis: Dictionary) -> String:
    if session == null:
        return ""
    return JSON.stringify({
        "session": session.to_dictionary(),
        "analysis": PlaytestValueEncoder.encode(analysis),
    }, "\t", true)


func build_markdown(
    session: PlaytestSession,
    analysis: Dictionary,
    locale: StringName = &"ru"
) -> String:
    if session == null:
        return ""
    var lines := PackedStringArray()
    lines.append("# %s" % PlaytestReportCatalog.text(&"report_title", locale).format({
        "id": session.id,
    }))
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"summary", locale))
    lines.append("")
    lines.append("- %s: `%s`" % [PlaytestReportCatalog.text(&"build", locale), session.build_revision])
    lines.append("- %s: %s" % [PlaytestReportCatalog.text(&"result", locale), _outcome(session, locale)])
    lines.append("- %s: %s" % [PlaytestReportCatalog.text(&"duration", locale), _duration(session.ended_elapsed_ms)])
    lines.append("- %s: %s" % [
        PlaytestReportCatalog.text(&"paused", locale),
        _duration(analysis.get("paused_ms", 0) as int),
    ])
    lines.append("- %s: %d" % [PlaytestReportCatalog.text(&"end_tick", locale), session.ended_tick])
    lines.append("- %s: %d" % [PlaytestReportCatalog.text(&"dropped_entries", locale), session.dropped_entries])
    _append_milestones(lines, analysis, locale)
    _append_speed_usage(lines, analysis, locale)
    _append_phase_durations(lines, analysis, locale)
    _append_commands(lines, analysis, locale)
    _append_idle(lines, analysis, locale)
    _append_difficulties(lines, analysis, locale)
    _append_layers(lines, analysis, locale)
    _append_diagnostics(lines, analysis, locale)
    _append_water(lines, analysis, locale)
    _append_bottlenecks(lines, analysis, locale)
    _append_unknown_events(lines, session, locale)
    _append_answers(lines, locale)
    return "\n".join(lines) + "\n"


func _append_milestones(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"milestones", locale))
    lines.append("")
    var milestones := analysis.get("milestones", {}) as Dictionary
    var keys := milestones.keys()
    keys.sort()
    var count := 0
    for key_value: Variant in keys:
        var key := str(key_value)
        var value := milestones[key_value] as int
        if value < 0:
            continue
        lines.append("- %s: %s" % [PlaytestReportCatalog.milestone(key, locale), _duration(value)])
        count += 1
    if count == 0:
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))


func _append_commands(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"commands", locale))
    lines.append("")
    var counts := analysis.get("command_counts", {}) as Dictionary
    lines.append("- %s: %d" % [PlaytestReportCatalog.text(&"accepted", locale), counts.get("accepted", 0)])
    lines.append("- %s: %d" % [PlaytestReportCatalog.text(&"rejected", locale), counts.get("rejected", 0)])


func _append_speed_usage(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"speeds", locale))
    lines.append("")
    var durations := analysis.get("speed_durations_ms", {}) as Dictionary
    if durations.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    var keys := durations.keys()
    keys.sort()
    for key: Variant in keys:
        lines.append("- ×%s: %s" % [key, _duration(durations[key] as int)])


func _append_phase_durations(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"phase_durations", locale))
    lines.append("")
    var durations := analysis.get("phase_durations_ms", {}) as Dictionary
    if durations.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    var keys := durations.keys()
    keys.sort()
    for key: Variant in keys:
        lines.append("- %s: %s" % [
            PlaytestReportCatalog.value("phase", str(key), locale),
            _duration(durations[key] as int),
        ])


func _append_idle(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"idle", locale))
    lines.append("")
    var periods := analysis.get("idle_periods", []) as Array
    if periods.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    for value: Variant in periods:
        var period := value as Dictionary
        lines.append("- %s–%s (%s)" % [
            _duration(period.get("start_ms", 0) as int),
            _duration(period.get("end_ms", 0) as int),
            _duration(period.get("duration_ms", 0) as int),
        ])


func _append_difficulties(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"difficulties", locale))
    lines.append("")
    var periods := analysis.get("idle_periods", []) as Array
    if periods.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    for value: Variant in periods:
        var period := value as Dictionary
        lines.append("- %s–%s — %s" % [
            _duration(period.get("start_ms", 0) as int),
            _duration(period.get("end_ms", 0) as int),
            PlaytestReportCatalog.value(
                "difficulty",
                period.get("category", "observer_review") as String,
                locale
            ),
        ])


func _append_layers(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"layers", locale))
    lines.append("")
    var usage := analysis.get("layer_usage", {}) as Dictionary
    if usage.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    var keys := usage.keys()
    keys.sort()
    for key: Variant in keys:
        lines.append("- %s: %d" % [
            PlaytestReportCatalog.value("layer", str(key), locale),
            usage[key],
        ])


func _append_diagnostics(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"diagnostics", locale))
    lines.append("")
    var counts := analysis.get("diagnostic_counts", {}) as Dictionary
    if counts.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    var keys := counts.keys()
    keys.sort()
    for key: Variant in keys:
        lines.append("- %s: %d" % [
            PlaytestReportCatalog.value("reason", str(key), locale),
            counts[key],
        ])


func _append_water(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"water_path", locale))
    lines.append("")
    var key := StringName("water.%s" % analysis.get("water_path", "none"))
    lines.append(PlaytestReportCatalog.text(key, locale))


func _append_bottlenecks(lines: PackedStringArray, analysis: Dictionary, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"bottlenecks", locale))
    lines.append("")
    var candidates := analysis.get("bottleneck_candidates", []) as Array
    if candidates.is_empty():
        lines.append("- %s" % PlaytestReportCatalog.text(&"none", locale))
        return
    for value: Variant in candidates:
        var candidate := value as Dictionary
        lines.append("- %s, %s → %s, %.1f → %.1f — %s" % [
            PlaytestReportCatalog.value(
                "action", candidate.get("action_code", "") as String, locale
            ),
            PlaytestReportCatalog.value(
                "reason", candidate.get("diagnostic_before", "") as String, locale
            ),
            PlaytestReportCatalog.value(
                "reason", candidate.get("diagnostic_after", "") as String, locale
            ),
            float(candidate.get("throughput_before", 0.0)),
            float(candidate.get("throughput_after", 0.0)),
            PlaytestReportCatalog.text(&"confirmed", locale),
        ])


func _append_unknown_events(
    lines: PackedStringArray,
    session: PlaytestSession,
    locale: StringName
) -> void:
    var unknown := PackedStringArray()
    for entry: PlaytestEntry in session.entries:
        if not PlaytestReportCatalog.is_known_event(entry.code):
            unknown.append(PlaytestReportCatalog.unknown_event(entry.code, locale))
    if unknown.is_empty():
        return
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"unknown_events", locale))
    lines.append("")
    for message: String in unknown:
        lines.append("- %s" % message)


func _append_answers(lines: PackedStringArray, locale: StringName) -> void:
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"player_answers", locale))
    lines.append("")
    for key: StringName in [&"question_1", &"question_2", &"question_3"]:
        lines.append("- **%s**  " % PlaytestReportCatalog.text(key, locale))
        lines.append("  ")
    lines.append("")
    lines.append("## %s" % PlaytestReportCatalog.text(&"observer_notes", locale))
    lines.append("")
    lines.append("")


func _outcome(session: PlaytestSession, locale: StringName) -> String:
    var key := StringName("outcome.%s" % session.outcome)
    if session.outcome.is_empty():
        key = &"outcome.unknown"
    return PlaytestReportCatalog.text(key, locale)


func _duration(milliseconds: int) -> String:
    var total_seconds := maxi(milliseconds, 0) / 1000
    return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
