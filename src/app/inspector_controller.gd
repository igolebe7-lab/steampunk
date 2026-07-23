class_name InspectorController
extends RefCounted

var _label: RichTextLabel
var _controls: Dictionary = {}
var selected_kind: StringName = &""
var selected_id: int = 0
var selected_coord: HexCoord


func configure(label: RichTextLabel, controls: Dictionary = {}) -> void:
    _label = label
    _controls = controls
    _label.text = tr(&"ui.inspector.empty")
    _set_controls_visible(false, false)


func show_selection(state: SimulationState, kind: StringName, entity_id: int, coord: HexCoord = null) -> void:
    selected_kind = kind
    selected_id = entity_id
    selected_coord = coord
    if _label != null:
        _label.text = build_text(state, kind, entity_id, coord)
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


func build_text(state: SimulationState, kind: StringName, entity_id: int, coord: HexCoord = null) -> String:
    if state == null:
        return tr(&"ui.inspector.empty")
    if kind == &"worker":
        return _worker_text(state.get_worker(entity_id))
    if kind == &"building":
        return _building_text(state, state.get_building(entity_id))
    if kind == &"link":
        return _link_text(state, state.logistics_links.get(entity_id) as LogisticsLinkState)
    if kind == &"utility_segment":
        return _utility_text(state, coord)
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
    var text := "%s\n%s" % [
        tr(&"ui.inspector.building").format({"id": building.id}),
        tr(definition.display_name_key),
    ]
    var inventory_text := _inventory_text(state, building, definition)
    if not inventory_text.is_empty():
        text += "\n%s" % inventory_text
    text += "\n%s" % tr(&"ui.inspector.building.body").format({
        "level": building.level,
        "priority": building.priority,
        "direct": tr(&"ui.value.yes") if building.allows_direct_delivery_to_main else tr(&"ui.value.no"),
    })
    var production := state.production_states.get(building.id) as ProductionState
    if production != null:
        text += "\n%s" % tr(&"ui.inspector.production.body").format({
            "status": tr(StringName("production.status.%s" % production.status)),
            "progress": production.progress_ticks,
            "heat": production.heat_level,
            "cycles": production.completed_cycles,
            "reason": tr(StringName("reason.%s" % production.blocked_reason)) if not production.blocked_reason.is_empty() else tr(&"ui.value.none"),
        })
    return text


func _inventory_text(
    state: SimulationState,
    building: BuildingState,
    definition: BuildingDef
) -> String:
    var resource_ids := _inventory_resource_ids(state, building, definition)
    if building.inventory_capacity <= 0 and resource_ids.is_empty():
        return ""
    var lines: Array[String] = [
        tr(&"ui.inspector.inventory.total").format({
            "inventory": building.inventory_total(),
            "capacity": building.inventory_capacity,
        }),
    ]
    for resource_id: StringName in resource_ids:
        var resource := state.catalog.get_resource(resource_id)
        var name := String(resource_id) if resource == null else tr(resource.display_name_key)
        lines.append(tr(&"ui.inspector.inventory.line").format({
            "name": name,
            "amount": building.get_amount(resource_id),
        }))
        var outgoing := building.get_outgoing_reserved(resource_id)
        if outgoing > 0:
            lines.append(tr(&"ui.inspector.inventory.outgoing").format({"amount": outgoing}))
        var incoming := building.get_incoming_reserved(resource_id)
        if incoming > 0:
            lines.append(tr(&"ui.inspector.inventory.incoming").format({"amount": incoming}))
    return "\n".join(lines)


func _inventory_resource_ids(
    state: SimulationState,
    building: BuildingState,
    definition: BuildingDef
) -> Array[StringName]:
    var relevant: Dictionary = {}
    var show_all := definition.role in [
        LogisticsPortDef.ROLE_MAIN_WAREHOUSE,
        LogisticsPortDef.ROLE_TRANSFER_DEPOT,
    ]
    if not definition.source_resource_id.is_empty():
        relevant[definition.source_resource_id] = true
    for port: LogisticsPortDef in definition.logistics_ports:
        relevant[port.resource_id] = true
    for inventory in [
        building.inventories,
        building.outgoing_reserved,
        building.incoming_reserved,
    ]:
        for resource_id: StringName in inventory:
            relevant[resource_id] = true

    var result: Array[StringName] = []
    for resource: ResourceDef in state.catalog.resources:
        if show_all or relevant.has(resource.id):
            result.append(resource.id)
            relevant.erase(resource.id)
    var unknown_ids: Array = relevant.keys()
    unknown_ids.sort()
    for resource_id: StringName in unknown_ids:
        result.append(resource_id)
    return result


func _utility_text(state: SimulationState, coord: HexCoord) -> String:
    var segment := state.utility_network.get_segment(coord)
    if segment == null:
        return tr(&"ui.inspector.empty")
    return tr(&"ui.inspector.utility.body").format({
        "q": coord.q,
        "r": coord.r,
        "commodity": tr(StringName("resource.%s.name" % segment.commodity_id)),
        "component": segment.component_id,
    })


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
