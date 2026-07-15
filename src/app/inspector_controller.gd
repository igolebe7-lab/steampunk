class_name InspectorController
extends RefCounted

var _label: RichTextLabel
var _controls: Dictionary = {}
var selected_kind: StringName = &""
var selected_id: int = 0


func configure(label: RichTextLabel, controls: Dictionary = {}) -> void:
    _label = label
    _controls = controls
    _label.text = tr(&"ui.inspector.empty")
    _set_controls_visible(false, false)


func show_selection(state: SimulationState, kind: StringName, entity_id: int) -> void:
    selected_kind = kind
    selected_id = entity_id
    if _label != null:
        _label.text = build_text(state, kind, entity_id)
    _refresh_controls(state)


func _refresh_controls(state: SimulationState) -> void:
    var link := state.logistics_links.get(selected_id) as LogisticsLinkState if state != null and selected_kind == &"link" else null
    var building := state.get_building(selected_id) if state != null and selected_kind == &"building" else null
    _set_controls_visible(link != null, building != null)
    if link != null:
        (_controls.get(&"quota") as SpinBox).value = link.quota
        (_controls.get(&"priority") as SpinBox).value = link.priority
        (_controls.get(&"dispatch") as CheckButton).button_pressed = link.dispatch_enabled
    if building != null:
        (_controls.get(&"direct_main") as CheckButton).button_pressed = building.allows_direct_delivery_to_main
        var definition := state.catalog.get_building(building.definition_id)
        var is_source := definition != null and definition.role == LogisticsPortDef.ROLE_SOURCE
        var direct_main := _controls.get(&"direct_main") as CheckButton
        var apply_direct := _controls.get(&"apply_direct") as Button
        var demolish := _controls.get(&"demolish") as Button
        if direct_main != null:
            direct_main.visible = is_source
        if apply_direct != null:
            apply_direct.visible = is_source
        if demolish != null:
            demolish.visible = definition != null and definition.role == LogisticsPortDef.ROLE_TRANSFER_DEPOT


func _set_controls_visible(link_visible: bool, building_visible: bool) -> void:
    var link_controls := _controls.get(&"link_controls") as Control
    var building_controls := _controls.get(&"building_controls") as Control
    if link_controls != null:
        link_controls.visible = link_visible
    if building_controls != null:
        building_controls.visible = building_visible


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
