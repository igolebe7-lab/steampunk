class_name InspectorController
extends RefCounted

var _label: RichTextLabel


func configure(label: RichTextLabel) -> void:
    _label = label
    _label.text = tr(&"ui.inspector.empty")


func show_selection(state: SimulationState, kind: StringName, entity_id: int) -> void:
    if _label != null:
        _label.text = build_text(state, kind, entity_id)


func build_text(state: SimulationState, kind: StringName, entity_id: int) -> String:
    if state == null:
        return tr(&"ui.inspector.empty")
    if kind == &"worker":
        return _worker_text(state.get_worker(entity_id))
    if kind == &"building":
        return _building_text(state, state.get_building(entity_id))
    if kind == &"link":
        return _link_text(state, state.logistics_links.get(entity_id) as LogisticsLinkState)
    return tr(&"ui.inspector.empty")


func _worker_text(worker: WorkerState) -> String:
    if worker == null:
        return tr(&"ui.inspector.empty")
    var reason := tr(&"ui.value.none") if worker.wait_reason.is_empty() or worker.wait_reason == &"no_job" else tr(StringName("reason.%s" % worker.wait_reason))
    var cargo := tr(&"ui.value.none") if worker.cargo_resource_id.is_empty() else tr(StringName("resource.%s.name" % worker.cargo_resource_id))
    return "%s\n%s" % [
        tr(&"ui.inspector.worker").format({"id": worker.id}),
        tr(&"ui.inspector.worker.body").format({
            "action": tr(StringName("action.%s" % worker.action)),
            "cargo": cargo,
            "reason": reason,
            "wait": worker.wait_ticks,
            "link": worker.link_id,
            "job": worker.job_id,
        }),
    ]


func _building_text(state: SimulationState, building: BuildingState) -> String:
    if building == null:
        return tr(&"ui.inspector.empty")
    var definition := state.catalog.get_building(building.definition_id)
    return "%s\n%s" % [
        tr(&"ui.inspector.building").format({"id": building.id}),
        tr(&"ui.inspector.building.body").format({
            "name": tr(definition.display_name_key),
            "inventory": building.inventory_total(),
            "capacity": building.inventory_capacity,
            "level": building.level,
            "priority": building.priority,
            "direct": tr(&"ui.value.yes") if building.allows_direct_delivery_to_main else tr(&"ui.value.no"),
        }),
    ]


func _link_text(state: SimulationState, link: LogisticsLinkState) -> String:
    if link == null:
        return tr(&"ui.inspector.empty")
    return "%s\n%s" % [
        tr(&"ui.inspector.link").format({"id": link.id}),
        tr(&"ui.inspector.link.body").format({
            "source": link.source_id,
            "destination": link.destination_id,
            "quota": link.quota,
            "priority": link.priority,
            "dispatch": tr(&"ui.value.yes") if link.dispatch_enabled else tr(&"ui.value.no"),
            "policy": tr(&"ui.value.auto") if link.is_automatic else tr(&"ui.value.manual"),
            "throughput": "%.1f" % state.telemetry_window.link_throughput_per_minute(link.id),
        }),
    ]
