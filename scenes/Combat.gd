extends Control

const MAX_FRONTLINE_SIZE: int = 4
const MAX_TURNS: int = 12
const RNG_STREAM_ACTION := "action"
const RNG_STREAM_AI := "ai"
const VARIANCE_MIN: float = 0.9
const VARIANCE_MAX: float = 1.1
const ATTACK_SKILL_ID: String = "attack_basic"

enum Phase {
	FORMATION,
	COMMAND,
	EXECUTION,
	COMPLETE,
}

const INFO_LABEL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/LogScroll/InfoLabel")
const CONTINUE_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/ButtonRow/CompleteButton")
const LOG_SCROLL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/LogScroll")
const PHASE_LABEL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/PhaseLabel")
const ALLIES_LIST_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/ArenaRow/AlliesPanel/AlliesList")
const ENEMIES_LIST_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/ArenaRow/EnemiesPanel/EnemiesList")
const COMMAND_PANEL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel")
const OPTIONS_SCROLL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/OptionsScroll")
const OPTIONS_LIST_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/OptionsScroll/OptionsList")
const TARGET_SCROLL_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/TargetScroll")
const TARGET_LIST_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/TargetScroll/TargetList")
const TARGET_PAYLOAD_META: StringName = StringName("target_payload")
const ATTACK_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/CommandButtons/AttackButton")
const SKILL_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/CommandButtons/SkillButton")
const SPELL_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/CommandButtons/SpellButton")
const ITEM_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/CommandButtons/ItemButton")
const GUARD_BUTTON_PATH: NodePath = NodePath("RootLayout/BodyMargin/Panel/VBox/CommandPanel/CommandButtons/GuardButton")

@onready var info_label: Label = get_node_or_null(INFO_LABEL_PATH)
@onready var continue_button: Button = get_node_or_null(CONTINUE_BUTTON_PATH)
@onready var log_scroll: ScrollContainer = get_node_or_null(LOG_SCROLL_PATH)
@onready var phase_label: Label = get_node_or_null(PHASE_LABEL_PATH)
@onready var allies_list: VBoxContainer = get_node_or_null(ALLIES_LIST_PATH)
@onready var enemies_list: VBoxContainer = get_node_or_null(ENEMIES_LIST_PATH)
@onready var command_panel: VBoxContainer = get_node_or_null(COMMAND_PANEL_PATH)
@onready var options_scroll: ScrollContainer = get_node_or_null(OPTIONS_SCROLL_PATH)
@onready var options_list: VBoxContainer = get_node_or_null(OPTIONS_LIST_PATH)
@onready var target_scroll: ScrollContainer = get_node_or_null(TARGET_SCROLL_PATH)
@onready var target_list: VBoxContainer = get_node_or_null(TARGET_LIST_PATH)
@onready var attack_button: Button = get_node_or_null(ATTACK_BUTTON_PATH)
@onready var skill_button: Button = get_node_or_null(SKILL_BUTTON_PATH)
@onready var spell_button: Button = get_node_or_null(SPELL_BUTTON_PATH)
@onready var item_button: Button = get_node_or_null(ITEM_BUTTON_PATH)
@onready var guard_button: Button = get_node_or_null(GUARD_BUTTON_PATH)

var _battle: BattleController
var _battle_log: Array[String] = []
var _phase: Phase = Phase.FORMATION
var _pending_commands: Array[BattleCommand] = []
var _current_actor_index: int = 0
var _current_actor: BattleEntity
var _cancel_target_callback: Callable = Callable()
var _formation_selection: BattleEntity
var _encounter_resolved: bool = false
var _battle_result: Dictionary = {}
var _turn_counter: int = 0
var _waiting_for_data: bool = false
var _using_fallback_party: bool = false

func _ready() -> void:
	_report_missing_ui_nodes()
	_connect_signals()
	_initialize_ui()
	_try_initialize_battle()

func _try_initialize_battle() -> void:
	if _is_data_ready():
		_initialize_battle()
		return
	var callback := Callable(self, "_on_data_ready")
	if not Data.data_loaded.is_connected(callback):
		Data.data_loaded.connect(callback, CONNECT_ONE_SHOT)
	if not _waiting_for_data:
		_waiting_for_data = true
		Data.load_all()

func _is_data_ready() -> bool:
	var skills_dataset: Variant = Data.get_dataset("skills")
	return skills_dataset is Array

func _on_data_ready() -> void:
	_waiting_for_data = false
	_initialize_battle()

func _report_missing_ui_nodes() -> void:
	if info_label == null:
		push_error("Combat scene is missing the info label at %s" % INFO_LABEL_PATH)
	if log_scroll == null:
		push_error("Combat scene is missing the log scroll container at %s" % LOG_SCROLL_PATH)
	if continue_button == null:
		push_error("Combat scene is missing the continue button at %s" % CONTINUE_BUTTON_PATH)
	if phase_label == null:
		push_error("Combat scene is missing the phase label at %s" % PHASE_LABEL_PATH)
	if allies_list == null:
		push_error("Combat scene is missing the allies list at %s" % ALLIES_LIST_PATH)
	if enemies_list == null:
		push_error("Combat scene is missing the enemies list at %s" % ENEMIES_LIST_PATH)
	if command_panel == null:
		push_error("Combat scene is missing the command panel at %s" % COMMAND_PANEL_PATH)

func _connect_signals() -> void:
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if attack_button != null:
		attack_button.pressed.connect(_on_attack_pressed)
	if skill_button != null:
		skill_button.pressed.connect(_on_skill_pressed)
	if spell_button != null:
		spell_button.pressed.connect(_on_spell_pressed)
	if item_button != null:
		item_button.pressed.connect(_on_item_pressed)
	if guard_button != null:
		guard_button.pressed.connect(_on_guard_pressed)

func _initialize_ui() -> void:
	if info_label != null:
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_label.text = tr("Encounter pending. Prepare for battle.")
	if command_panel != null:
		command_panel.visible = false
	if options_scroll != null:
		options_scroll.visible = false
	if target_scroll != null:
		target_scroll.visible = false
	if phase_label != null:
		phase_label.text = tr("Formation phase: adjust your party before fighting.")
	if continue_button != null:
		continue_button.disabled = false
		continue_button.text = tr("Confirm Formation")

func _initialize_battle() -> void:
	_waiting_for_data = false
	_using_fallback_party = false
	_battle_log.clear()
	_pending_commands.clear()
	_current_actor = null
	_formation_selection = null
	_cancel_target_callback = Callable()
	_battle_result = {}
	_encounter_resolved = false
	_turn_counter = 0
	var party_overview: Array[Dictionary] = _resolve_party_overview()
	var enemy_wave: Array[Dictionary] = _select_enemy_wave(Game.get_current_act())
	_battle = BattleController.new(party_overview, enemy_wave, MAX_FRONTLINE_SIZE)
	_append_log(tr("Battle begins!"))
	_refresh_entity_panels()
	_update_log_label()
	_enter_phase(Phase.FORMATION)

func _resolve_party_overview() -> Array[Dictionary]:
	var party_overview: Array[Dictionary] = Game.get_party_overview()
	if not party_overview.is_empty():
		return party_overview
	_using_fallback_party = true
	var fallback_templates: Array[Dictionary] = Data.create_default_party()
	var resolved: Array[Dictionary] = []
	for template in fallback_templates:
		resolved.append(template.duplicate(true))
	if not resolved.is_empty():
		push_warning("Party overview was empty; using default party templates for combat.")
		return resolved
	push_error("Unable to resolve party data for combat. Using minimal fallback party.")
	resolved.append(_build_default_ally("Vanguard", 100, 20, 12, 8, 10, 6, [ATTACK_SKILL_ID]))
	return resolved

func _build_default_ally(name: String, hp: int, mp: int, atk: int, def_stat: int, agi: int, matk: int, skills: Array[String]) -> Dictionary:
	return {
		"id": "fallback_ally",
		"name": name,
		"hp": hp,
		"max_hp": hp,
		"mp": mp,
		"max_mp": mp,
		"atk": atk,
		"def": def_stat,
		"agi": agi,
		"matk": matk,
		"rec": 5,
		"skills": skills,
	}

func _enter_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match _phase:
		Phase.FORMATION:
			_formation_selection = null
			_pending_commands.clear()
			_current_actor_index = 0
			_current_actor = null
			_clear_options()
			_clear_targets()
			_set_command_panel_visible(false)
			if phase_label != null:
				phase_label.text = tr("Formation phase: select two allies to swap positions or confirm to proceed.")
			if continue_button != null:
				continue_button.text = tr("Confirm Formation")
				continue_button.disabled = false
		Phase.COMMAND:
			var promoted_allies: Array[BattleEntity] = _battle.refresh_frontline()
			for ally in promoted_allies:
				_append_log(tr("%s moves into the frontline.") % ally.name)
			_refresh_entity_panels()
			_current_actor_index = 0
			_current_actor = null
			_clear_options()
			_clear_targets()
			_set_command_panel_visible(true)
			if phase_label != null:
				phase_label.text = tr("Command phase: choose actions for each frontline ally.")
			if continue_button != null:
				continue_button.text = tr("Execute Turn")
				continue_button.disabled = true
			_prepare_next_actor()
		Phase.EXECUTION:
			_set_command_panel_visible(false)
			if phase_label != null:
				phase_label.text = tr("Turn resolving...")
			if continue_button != null:
				continue_button.disabled = true
			_execute_turn()
		Phase.COMPLETE:
			_set_command_panel_visible(false)
			_clear_options()
			_clear_targets()
			if continue_button != null:
				continue_button.disabled = false
			if _battle_result.get("victory", false):
				if phase_label != null:
					phase_label.text = tr("Victory! Collect your rewards.")
				if continue_button != null:
					continue_button.text = tr("Collect Rewards")
			elif _battle_result.get("escaped", false):
				if phase_label != null:
					phase_label.text = tr("You fled from battle.")
				if continue_button != null:
					continue_button.text = tr("Return to Map")
			else:
				if phase_label != null:
					phase_label.text = tr("Defeat... the party has fallen.")
				if continue_button != null:
					continue_button.text = tr("Return to Map")
	_update_log_label()

func _set_command_panel_visible(visible: bool) -> void:
	if command_panel != null:
		command_panel.visible = visible
	if options_scroll != null:
		options_scroll.visible = false
	if target_scroll != null:
		target_scroll.visible = false
	_set_command_buttons_enabled(visible)

func _set_command_buttons_enabled(enabled: bool) -> void:
	if attack_button != null:
		attack_button.disabled = not enabled
	if skill_button != null:
		skill_button.disabled = not enabled
	if spell_button != null:
		spell_button.disabled = not enabled
	if item_button != null:
		item_button.disabled = not enabled
	if guard_button != null:
		guard_button.disabled = not enabled

func _prepare_next_actor() -> void:
	if _phase != Phase.COMMAND:
		return
	var frontline: Array[BattleEntity] = _battle.get_frontline_allies()
	while _current_actor_index < frontline.size() and (frontline[_current_actor_index] == null or not frontline[_current_actor_index].is_alive()):
		_current_actor_index += 1
	if _current_actor_index >= frontline.size():
		_current_actor = null
		_set_command_buttons_enabled(false)
		if continue_button != null:
			continue_button.disabled = _pending_commands.is_empty()
		if phase_label != null:
			phase_label.text = tr("All commands selected. Execute the turn when ready.")
		return
	_current_actor = frontline[_current_actor_index]
	_set_command_buttons_enabled(true)
	_configure_command_buttons_for_actor(_current_actor)
	if phase_label != null:
		phase_label.text = tr("Select a command for %s.") % _current_actor.name

func _configure_command_buttons_for_actor(actor: BattleEntity) -> void:
	if actor == null:
		_set_command_buttons_enabled(false)
		return
	if attack_button != null:
		attack_button.disabled = not actor.is_alive()
	if guard_button != null:
		guard_button.disabled = not actor.is_alive()
	var skill_options: Array[Dictionary] = _available_skills(actor, "skill")
	if skill_button != null:
		skill_button.disabled = skill_options.is_empty()
	var spell_options: Array[Dictionary] = _available_skills(actor, "spell")
	if spell_button != null:
		spell_button.disabled = spell_options.is_empty()
	if item_button != null:
		item_button.disabled = Game.get_inventory().is_empty()

func _available_skills(actor: BattleEntity, type_filter: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if actor == null:
		return results
	for skill_id in actor.skills:
		if skill_id == ATTACK_SKILL_ID:
			continue
		var skill: Dictionary = Data.get_skill_by_id(skill_id)
		if skill.is_empty():
			continue
		var skill_type: String = str(skill.get("type", "skill"))
		if skill_type != type_filter:
			continue
		results.append(skill)
	return results

func _refresh_entity_panels() -> void:
	_populate_entity_list(allies_list, _battle.get_all_allies(), true)
	_populate_entity_list(enemies_list, _battle.get_all_enemies(), false)

func _populate_entity_list(container: VBoxContainer, entities: Array[BattleEntity], is_ally: bool) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for entity in entities:
		var button := Button.new()
		button.text = _format_entity_text(entity, is_ally)
		button.disabled = not entity.is_alive()
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("entity", entity)
		if is_ally:
			button.pressed.connect(Callable(self, "_on_ally_entry_pressed").bind(button))
		container.add_child(button)

func _format_entity_text(entity: BattleEntity, is_ally: bool) -> String:
	var prefix: String = "[F]" if entity.frontline else "[R]"
	if not is_ally:
		prefix = "[Enemy]"
	var status_text: String = ""
	if not entity.statuses.is_empty():
		var labels: Array[String] = []
		for key in entity.statuses.keys():
			labels.append(str(key).capitalize())
		status_text = " | %s" % ", ".join(labels)
	if entity.guard_active:
		status_text += " | Guard"
	if not entity.is_alive():
		status_text += " | Down"
	var hp_text: String = "%d/%d" % [entity.hp, entity.max_hp]
	var mp_text: String = "%d/%d" % [entity.mp, entity.max_mp]
	return "%s %s\nHP %s | MP %s%s" % [prefix, entity.name, hp_text, mp_text, status_text]

func _append_log(entry: String) -> void:
	_battle_log.append(entry)
	_update_log_label()

func _update_log_label() -> void:
	if info_label == null:
		return
	info_label.text = "\n".join(_battle_log)
	_scroll_log_to_bottom()

func _scroll_log_to_bottom() -> void:
	if log_scroll == null:
		return
	var vbar := log_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	log_scroll.call_deferred("set", "scroll_vertical", int(vbar.max_value))

func _clear_options() -> void:
	if options_list == null:
		return
	for child in options_list.get_children():
		child.queue_free()
	if options_scroll != null:
		options_scroll.visible = false

func _clear_targets() -> void:
	_clear_target_buttons()
	if target_scroll != null:
		target_scroll.visible = false
	_cancel_target_callback = Callable()

func _clear_target_buttons() -> void:
	if target_list == null:
		return
	for child in target_list.get_children():
		child.queue_free()

func _show_options(buttons: Array[Dictionary]) -> void:
	_clear_options()
	if options_scroll == null or options_list == null:
		return
	if buttons.is_empty():
		options_scroll.visible = false
		return
	options_scroll.visible = true
	for button_data in buttons:
		var option_button := Button.new()
		option_button.text = str(button_data.get("text", "Option"))
		option_button.disabled = bool(button_data.get("disabled", false))
		option_button.focus_mode = Control.FOCUS_NONE
		option_button.tooltip_text = str(button_data.get("tooltip", ""))
		var callback: Variant = button_data.get("callback")
		if callback is Callable and (callback as Callable).is_valid():
			option_button.pressed.connect(callback)
		options_list.add_child(option_button)

func _show_target_options(buttons: Array[Dictionary], label: String, cancelable: bool = true) -> void:
	if target_scroll == null or target_list == null:
		return
	_clear_target_buttons()
	if buttons.is_empty():
		target_scroll.visible = false
		return
	target_scroll.visible = true
	if phase_label != null:
		phase_label.text = label
	for button_data in buttons:
		var button := Button.new()
		button.text = str(button_data.get("text", "Target"))
		button.disabled = bool(button_data.get("disabled", false))
		button.focus_mode = Control.FOCUS_NONE
		var payload_variant: Variant = button_data.get("payload")
		if not button.disabled and payload_variant is Dictionary:
			var payload: Dictionary = payload_variant
			button.set_meta(TARGET_PAYLOAD_META, payload)
			button.pressed.connect(Callable(self, "_on_target_button_pressed").bind(button))
		else:
			var callback_variant: Variant = button_data.get("callback")
			if callback_variant is Callable:
				var callable: Callable = callback_variant
				if callable.is_valid():
					button.pressed.connect(callable)
		target_list.add_child(button)
	if cancelable:
		var cancel_button := Button.new()
		cancel_button.text = tr("Cancel")
		cancel_button.focus_mode = Control.FOCUS_NONE
		cancel_button.pressed.connect(Callable(self, "_cancel_target_selection"))
		target_list.add_child(cancel_button)

func _on_target_button_pressed(button: Button) -> void:
	if button == null:
		return
	if not button.has_meta(TARGET_PAYLOAD_META):
		return
	var payload_variant: Variant = button.get_meta(TARGET_PAYLOAD_META)
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = payload_variant
	if payload.is_empty():
		return
	var mode: String = str(payload.get("mode", ""))
	match mode:
		"skill":
			_handle_skill_target_payload(payload)
		"item":
			_handle_item_target_payload(payload)
		_:
			pass

func _handle_skill_target_payload(payload: Dictionary) -> void:
	var target: BattleEntity = _resolve_payload_entity(payload, "target")
	if target == null or not target.is_alive():
		return
	var actor: BattleEntity = _resolve_payload_entity(payload, "actor")
	if actor == null or not actor.is_alive():
		return
	var skill_variant: Variant = payload.get("skill")
	var skill_dict: Dictionary = {}
	if typeof(skill_variant) == TYPE_DICTIONARY:
		skill_dict = skill_variant
	_on_skill_target_selected(target, actor, skill_dict)

func _handle_item_target_payload(payload: Dictionary) -> void:
	var target: BattleEntity = _resolve_payload_entity(payload, "target")
	if target == null:
		return
	var actor: BattleEntity = _resolve_payload_entity(payload, "actor")
	if actor == null or not actor.is_alive():
		return
	var slot_index: int = int(payload.get("slot_index", -1))
	var item_variant: Variant = payload.get("item_data")
	var item_dict: Dictionary = {}
	if typeof(item_variant) == TYPE_DICTIONARY:
		item_dict = item_variant
	_on_item_target_selected(target, actor, slot_index, item_dict)

func _resolve_payload_entity(payload: Dictionary, key: String) -> BattleEntity:
	if payload.is_empty():
		return null
	var value: Variant = payload.get(key)
	if value == null:
		return null
	if value is BattleEntity:
		return value
	if value is WeakRef:
		var weak: WeakRef = value
		var referenced: Object = weak.get_ref()
		if referenced is BattleEntity:
			return referenced
		if referenced is Object:
			var instance_object: Object = referenced
			var candidate: BattleEntity = _resolve_entity_by_instance_id(instance_object.get_instance_id())
			if candidate != null:
				return candidate
		return null
	if value is RefCounted:
		var refcounted: RefCounted = value
		var candidate_from_ref: BattleEntity = _resolve_entity_by_instance_id(refcounted.get_instance_id())
		if candidate_from_ref != null:
			return candidate_from_ref
	var instance_id: int = int(payload.get("%s_instance_id" % key, 0))
	if instance_id != 0:
		return _resolve_entity_by_instance_id(instance_id)
	return null

func _build_skill_target_payload(actor: BattleEntity, target: BattleEntity, skill: Dictionary) -> Dictionary:
	return {
		"mode": "skill",
		"target": target,
		"target_instance_id": target.get_instance_id(),
		"actor": actor,
		"actor_instance_id": actor.get_instance_id(),
		"skill": skill.duplicate(true),
	}

func _build_item_target_payload(actor: BattleEntity, target: BattleEntity, slot_index: int, item_data: Dictionary) -> Dictionary:
	return {
		"mode": "item",
		"target": target,
		"target_instance_id": target.get_instance_id(),
		"actor": actor,
		"actor_instance_id": actor.get_instance_id(),
		"slot_index": slot_index,
		"item_data": item_data.duplicate(true),
	}

func _resolve_entity_by_instance_id(instance_id: int) -> BattleEntity:
	if instance_id == 0 or _battle == null:
		return null
	for ally in _battle.get_all_allies():
		if ally != null and ally.get_instance_id() == instance_id:
			return ally
	for enemy in _battle.get_all_enemies():
		if enemy != null and enemy.get_instance_id() == instance_id:
			return enemy
	return null

func _cancel_target_selection() -> void:
	_clear_targets()
	if _cancel_target_callback.is_valid():
		_cancel_target_callback.call()

func _on_ally_entry_pressed(button: Button) -> void:
	if button == null:
		return
	if _phase != Phase.FORMATION:
		return
	var entity: Variant = button.get_meta("entity")
	if not (entity is BattleEntity):
		return
	var ally: BattleEntity = entity
	if _formation_selection == null:
		_formation_selection = ally
		if phase_label != null:
			phase_label.text = tr("Selected %s. Choose another ally to swap.") % ally.name
		return
	if _formation_selection == ally:
		_formation_selection = null
		if phase_label != null:
			phase_label.text = tr("Selection cleared. Choose two allies to swap or confirm.")
		return
	var first: BattleEntity = _formation_selection
	var swapped: bool = _battle.swap_allies(first, ally)
	_formation_selection = null
	_refresh_entity_panels()
	if swapped:
		_append_log(tr("%s and %s swap positions.") % [first.name, ally.name])
		if phase_label != null:
			phase_label.text = tr("Swap complete. Select another pair or confirm formation.")
	else:
		if phase_label != null:
			phase_label.text = tr("Unable to swap those allies. Select a frontline and a reserve member.")

func _on_continue_pressed() -> void:
	match _phase:
		Phase.FORMATION:
			var promoted: Array[BattleEntity] = _battle.refresh_frontline()
			for ally in promoted:
				_append_log(tr("%s moves into the frontline.") % ally.name)
			_refresh_entity_panels()
			_enter_phase(Phase.COMMAND)
		Phase.COMMAND:
			if _pending_commands.is_empty():
				if phase_label != null:
					phase_label.text = tr("Assign actions to your frontline allies before executing the turn.")
				return
			_enter_phase(Phase.EXECUTION)
		Phase.COMPLETE:
			if _battle_result.get("victory", false):
				Game.open_rewards()
			else:
				Game.set_state(Game.GameState.MAP)
		_:
			pass

func _on_attack_pressed() -> void:
	if _current_actor == null or not _current_actor.is_alive():
		return
	var skill: Dictionary = _get_skill_or_default(ATTACK_SKILL_ID)
	_prompt_for_skill(_current_actor, skill)

func _on_skill_pressed() -> void:
	if _current_actor == null:
		return
	var options: Array[Dictionary] = _available_skills(_current_actor, "skill")
	if options.is_empty():
		_show_options([{ "text": tr("No skills available"), "disabled": true }])
		return
	var buttons: Array[Dictionary] = []
	for skill in options:
		var name: String = _localize_skill_name(skill)
		var cost: int = int(skill.get("cost_mp", 0))
		var text: String = "%s (MP %d)" % [name, cost]
		var disabled: bool = cost > _current_actor.mp
		buttons.append({
			"text": text,
			"disabled": disabled,
			"callback": Callable(self, "_on_skill_option_selected").bind(skill),
		})
	buttons.append({
		"text": tr("Cancel"),
		"callback": Callable(self, "_on_cancel_option_selection"),
	})
	_show_options(buttons)

func _on_spell_pressed() -> void:
	if _current_actor == null:
		return
	var options: Array[Dictionary] = _available_skills(_current_actor, "spell")
	if options.is_empty():
		_show_options([{ "text": tr("No spells available"), "disabled": true }])
		return
	var buttons: Array[Dictionary] = []
	for skill in options:
		var name: String = _localize_skill_name(skill)
		var cost: int = int(skill.get("cost_mp", 0))
		var text: String = "%s (MP %d)" % [name, cost]
		var disabled: bool = cost > _current_actor.mp or (_current_actor.has_status("silence") and str(skill.get("type", "skill")) == "spell")
		buttons.append({
			"text": text,
			"disabled": disabled,
			"callback": Callable(self, "_on_skill_option_selected").bind(skill),
		})
	buttons.append({
		"text": tr("Cancel"),
		"callback": Callable(self, "_on_cancel_option_selection"),
	})
	_show_options(buttons)

func _on_cancel_option_selection() -> void:
	_clear_options()

func _on_skill_option_selected(skill: Dictionary) -> void:
	_clear_options()
	if _current_actor == null or not _current_actor.is_alive():
		return
	_prompt_for_skill(_current_actor, skill)

func _prompt_for_skill(actor: BattleEntity, skill: Dictionary) -> void:
	if skill.is_empty():
		_append_log(tr("%s has no usable skill.") % actor.name)
		return
	var resolved_skill: Dictionary = skill.duplicate(true)
	var cost: int = int(resolved_skill.get("cost_mp", 0))
	if cost > actor.mp:
		_append_log(tr("%s lacks the MP to use %s.") % [actor.name, _localize_skill_name(resolved_skill)])
		return
	var target_mode: String = str(resolved_skill.get("target", "enemy_single"))
	match target_mode:
		"enemy_single":
			var targets: Array[BattleEntity] = _battle.get_live_enemies()
			if targets.size() == 1:
				_register_skill_command(actor, resolved_skill, [targets[0]])
				return
			var buttons: Array[Dictionary] = []
			for target in targets:
				var disabled: bool = not target.is_alive()
				var button_entry: Dictionary = {
					"text": "%s (%d/%d HP)" % [target.name, target.hp, target.max_hp],
					"disabled": disabled,
				}
				if not disabled:
					button_entry["payload"] = _build_skill_target_payload(actor, target, resolved_skill)
				buttons.append(button_entry)
			_cancel_target_callback = Callable(self, "_restore_command_prompt")
			_show_target_options(buttons, tr("Select an enemy target."))
		"ally_single":
			var allies: Array[BattleEntity] = _battle.get_live_allies()
			if allies.size() == 1:
				_register_skill_command(actor, resolved_skill, [allies[0]])
				return
			var ally_buttons: Array[Dictionary] = []
			for ally in allies:
				var disabled: bool = not ally.is_alive()
				var ally_entry: Dictionary = {
					"text": "%s (%d/%d HP)" % [ally.name, ally.hp, ally.max_hp],
					"disabled": disabled,
				}
				if not disabled:
					ally_entry["payload"] = _build_skill_target_payload(actor, ally, resolved_skill)
				ally_buttons.append(ally_entry)
			_cancel_target_callback = Callable(self, "_restore_command_prompt")
			_show_target_options(ally_buttons, tr("Select an ally target."))
		"enemy_all":
			_register_skill_command(actor, resolved_skill, _battle.get_live_enemies())
		"ally_all":
			_register_skill_command(actor, resolved_skill, _battle.get_live_allies())
		_:
			_register_skill_command(actor, resolved_skill, _battle.get_live_enemies())

func _on_skill_target_selected(target: BattleEntity, actor: BattleEntity, skill: Dictionary) -> void:
	_clear_targets()
	_register_skill_command(actor, skill, [target])

func _restore_command_prompt() -> void:
	if _current_actor != null and phase_label != null:
		phase_label.text = tr("Select a command for %s.") % _current_actor.name

func _register_skill_command(actor: BattleEntity, skill: Dictionary, targets: Array[BattleEntity]) -> void:
	var command := BattleCommand.new(actor, BattleCommand.TYPE_SKILL)
	command.skill = skill.duplicate(true)
	command.targets = targets.duplicate()
	_commit_command(command)

func _on_guard_pressed() -> void:
	if _current_actor == null or not _current_actor.is_alive():
		return
	var command := BattleCommand.new(_current_actor, BattleCommand.TYPE_GUARD)
	_commit_command(command)

func _on_item_pressed() -> void:
	var inventory: Array[Dictionary] = Game.get_inventory()
	if inventory.is_empty():
		_show_options([{ "text": tr("No items in inventory"), "disabled": true }])
		return
	var buttons: Array[Dictionary] = []
	for index in range(inventory.size()):
		var entry: Dictionary = inventory[index]
		var item_id: String = str(entry.get("id", ""))
		if item_id == "":
			continue
		var quantity: int = int(entry.get("quantity", 1))
		var item_data: Dictionary = Data.get_item_by_id(item_id)
		var name: String = item_id
		if not item_data.is_empty():
			name = _localize_item_name(item_data)
		var text: String = "%s x%d" % [name, quantity]
		buttons.append({
			"text": text,
			"disabled": quantity <= 0,
			"callback": Callable(self, "_on_item_option_selected").bind(index, item_data),
		})
	buttons.append({
		"text": tr("Cancel"),
		"callback": Callable(self, "_on_cancel_option_selection"),
	})
	_show_options(buttons)

func _on_item_option_selected(slot_index: int, item_data: Dictionary) -> void:
	_clear_options()
	if _current_actor == null or not _current_actor.is_alive():
		return
	var actor_ref: BattleEntity = _current_actor
	var effect: String = str(item_data.get("effect", ""))
	var item_id: String = str(item_data.get("id", ""))
	match effect:
		"heal_hp", "heal_mp":
			var targets: Array[BattleEntity] = _battle.get_live_allies()
			if targets.is_empty():
				_append_log(tr("No allies can receive the item."))
				return
			var item_buttons: Array[Dictionary] = []
			for target in targets:
				var disabled: bool = not target.is_alive()
				var entry: Dictionary = {
					"text": "%s (%d/%d HP)" % [target.name, target.hp, target.max_hp],
					"disabled": disabled,
				}
				if not disabled:
					entry["payload"] = _build_item_target_payload(actor_ref, target, slot_index, item_data)
				item_buttons.append(entry)
			_cancel_target_callback = Callable(self, "_restore_command_prompt")
			_show_target_options(item_buttons, tr("Select an ally for %s.") % _localize_item_name(item_data))
		"escape":
			var command := BattleCommand.new(actor_ref, BattleCommand.TYPE_ITEM)
			command.item_id = item_id
			command.item_slot = slot_index
			command.item_effect = effect
			command.item_payload = item_data.duplicate(true)
			_commit_command(command)
		_:
			var command_default := BattleCommand.new(actor_ref, BattleCommand.TYPE_ITEM)
			command_default.item_id = item_id
			command_default.item_slot = slot_index
			command_default.item_effect = effect
			command_default.item_payload = item_data.duplicate(true)
			_commit_command(command_default)

func _on_item_target_selected(target: BattleEntity, actor: BattleEntity, slot_index: int, item_data: Dictionary) -> void:
	_clear_targets()
	if actor == null or not actor.is_alive():
		return
	var command := BattleCommand.new(actor, BattleCommand.TYPE_ITEM)
	command.item_id = str(item_data.get("id", ""))
	command.item_slot = slot_index
	command.item_effect = str(item_data.get("effect", ""))
	command.targets = [target]
	command.item_payload = item_data.duplicate(true)
	_commit_command(command)

func _commit_command(command: BattleCommand) -> void:
	_pending_commands.append(command)
	_current_actor_index += 1
	_current_actor = null
	_clear_options()
	_clear_targets()
	_prepare_next_actor()

func _execute_turn() -> void:
	_turn_counter += 1
	_append_log("=== %s ===" % (tr("Turn %d") % _turn_counter))
	var promoted: Array[BattleEntity] = _battle.refresh_frontline()
	for ally in promoted:
		_append_log(tr("%s moves into the frontline.") % ally.name)
	var order: Array[BattleEntity] = _battle.build_turn_order()
	var ally_commands: Dictionary = {}
	for command in _pending_commands:
		ally_commands[command.actor] = command
	var enemy_commands: Dictionary = _build_enemy_commands()
	for entity in order:
		if _battle.is_battle_over():
			break
		if entity == null or not entity.is_alive():
			continue
		if entity.guard_active:
			entity.guard_active = false
		if entity.has_status("sleep"):
			_append_log(tr("%s is fast asleep.") % entity.name)
			entity.tick_status("sleep")
			continue
		if entity.is_enemy:
			var enemy_command: BattleCommand = enemy_commands.get(entity, null)
			if enemy_command == null:
				continue
			_resolve_command(enemy_command)
			if _encounter_resolved:
				break
		else:
			var ally_command: BattleCommand = ally_commands.get(entity, null)
			if ally_command == null:
				_append_log(tr("%s hesitates and loses the turn.") % entity.name)
			else:
				_resolve_command(ally_command)
			if _encounter_resolved:
				break
	_pending_commands.clear()
	_current_actor_index = 0
	_current_actor = null
	_refresh_entity_panels()
	if _encounter_resolved:
		return
	_battle.end_of_turn(_battle_log)
	if _battle.is_battle_over() or _turn_counter >= MAX_TURNS:
		_finalize_battle()
	else:
		_enter_phase(Phase.FORMATION)

func _build_enemy_commands() -> Dictionary:
	var commands: Dictionary = {}
	for enemy in _battle.get_live_enemies():
		var command := BattleCommand.new(enemy, BattleCommand.TYPE_SKILL)
		var skill: Dictionary = _choose_enemy_skill(enemy)
		if skill.is_empty():
			command.command_type = BattleCommand.TYPE_GUARD
		else:
			command.skill = skill
			command.targets = _enemy_targets_for_skill(enemy, skill)
		commands[enemy] = command
	return commands

func _choose_enemy_skill(enemy: BattleEntity) -> Dictionary:
	for skill_id in enemy.skills:
		var skill: Dictionary = _get_skill_or_default(skill_id)
		if skill.is_empty():
			continue
		var cost: int = int(skill.get("cost_mp", 0))
		if cost > enemy.mp:
			continue
		var skill_type: String = str(skill.get("type", "skill"))
		if skill_type == "spell" and enemy.has_status("silence"):
			continue
		return skill
	return Dictionary()

func _enemy_targets_for_skill(enemy: BattleEntity, skill: Dictionary) -> Array[BattleEntity]:
	var target_mode: String = str(skill.get("target", "enemy_single"))
	match target_mode:
		"ally_single":
			var pool: Array[BattleEntity] = _battle.get_live_enemies() if not enemy.is_enemy else _battle.get_live_allies()
			return [] if pool.is_empty() else [pool[0]]
		"enemy_all":
			return _battle.get_live_allies() if enemy.is_enemy else _battle.get_live_enemies()
		"ally_all":
			return _battle.get_live_enemies() if enemy.is_enemy else _battle.get_live_allies()
		_:
			var opponents: Array[BattleEntity] = _battle.get_live_allies() if enemy.is_enemy else _battle.get_live_enemies()
			if opponents.is_empty():
				return []
			var frontline: Array[BattleEntity] = _battle.get_live_frontline_allies() if enemy.is_enemy else opponents
			if enemy.is_enemy and not frontline.is_empty():
				opponents = frontline
			var choice: BattleEntity = RNG.choice(RNG_STREAM_AI, opponents)
			if choice == null:
				choice = opponents[0]
			return [choice]

func _resolve_command(command: BattleCommand) -> void:
	match command.command_type:
		BattleCommand.TYPE_GUARD:
			_guard(command.actor)
		BattleCommand.TYPE_ITEM:
			_execute_item(command)
		BattleCommand.TYPE_SKILL:
			if command.skill.is_empty():
				_guard(command.actor)
			else:
				_execute_skill(command.actor, command.skill, command.targets)
		_:
			_guard(command.actor)

func _execute_skill(attacker: BattleEntity, skill: Dictionary, targets: Array[BattleEntity]) -> void:
	if attacker == null or skill.is_empty():
		return
	if targets.is_empty():
		_append_log(tr("%s's %s has no targets.") % [attacker.name, _localize_skill_name(skill)])
		return
	var cost: int = int(skill.get("cost_mp", 0))
	if cost > 0:
		if attacker.mp < cost:
			_append_log(tr("%s tries to use %s but lacks MP.") % [attacker.name, _localize_skill_name(skill)])
			return
		attacker.mp = max(0, attacker.mp - cost)
	var is_spell: bool = str(skill.get("type", "skill")) == "spell"
	var power: float = float(skill.get("power", 1.0))
	var name: String = _localize_skill_name(skill)
	for target in targets:
		if target == null or not target.is_alive():
			continue
		var variance: float = RNG.randf_range(RNG_STREAM_ACTION, VARIANCE_MIN, VARIANCE_MAX)
		var has_crit: bool = _roll_crit(attacker)
		var crit_multiplier: float = Balance.crit_multiplier(has_crit)
		var damage: int
		if is_spell:
			damage = Balance.magical_damage(attacker.get_stat("matk"), 1.0, power, variance, crit_multiplier, 1.0, target.guard_active)
		else:
			damage = Balance.physical_damage(attacker.get_stat("atk"), target.get_stat("def"), 1.0, power, variance, crit_multiplier, 1.0, target.guard_active)
		var prefix: String = "%s uses %s" % [attacker.name, name]
		if has_crit:
			prefix += " (CRIT!)"
		prefix += " on %s" % target.name
		_append_log("%s for %d damage." % [prefix, damage])
		_apply_damage(target, damage)
		if _battle.is_battle_over():
			break

func _execute_item(command: BattleCommand) -> void:
	var actor: BattleEntity = command.actor
	if actor == null:
		return
	if command.item_id == "":
		_append_log(tr("%s fumbles with an item but nothing happens.") % actor.name)
		return
	var consumed: bool = _consume_battle_item(command.item_slot, command.item_id)
	if not consumed:
		_append_log(tr("%s tries to use %s, but there are none left.") % [actor.name, command.item_id])
		return
	var item_data: Dictionary = command.item_payload
	if item_data.is_empty():
		item_data = Data.get_item_by_id(command.item_id)
	var name: String = _localize_item_name(item_data)
	match command.item_effect:
		"heal_hp":
			var amount: int = int(item_data.get("value", 0))
			var target: BattleEntity = actor if command.targets.is_empty() else command.targets[0]
			var healed: int = target.heal_hp(amount)
			_append_log(tr("%s uses %s on %s, restoring %d HP.") % [actor.name, name, target.name, healed])
		"heal_mp":
			var amount_mp: int = int(item_data.get("value", 0))
			var target_mp: BattleEntity = actor if command.targets.is_empty() else command.targets[0]
			var restored: int = target_mp.restore_mp(amount_mp)
			_append_log(tr("%s uses %s on %s, restoring %d MP.") % [actor.name, name, target_mp.name, restored])
		"escape":
			_append_log(tr("%s uses %s and flees the battle!") % [actor.name, name])
			_battle_result = {
				"victory": false,
				"party_defeated": false,
				"escaped": true,
				"turns": _turn_counter,
			}
			_apply_party_results(_battle.party_snapshot())
			_encounter_resolved = true
			_enter_phase(Phase.COMPLETE)
		_:
			_append_log(tr("%s uses %s, but nothing obvious happens.") % [actor.name, name])

func _consume_battle_item(slot_index: int, item_id: String, quantity: int = 1) -> bool:
	var inventory: Array[Dictionary] = Game.get_inventory()
	if slot_index >= 0 and slot_index < inventory.size():
		var entry: Dictionary = inventory[slot_index]
		if str(entry.get("id", "")) == item_id:
			return Game.consume_inventory_item(slot_index, quantity)
	for idx in range(inventory.size()):
		var alt: Dictionary = inventory[idx]
		if str(alt.get("id", "")) == item_id:
			return Game.consume_inventory_item(idx, quantity)
	return false

func _apply_damage(target: BattleEntity, damage: int) -> void:
	damage = max(0, damage)
	if damage <= 0:
		_append_log(tr("No damage was dealt to %s.") % target.name)
		return
	target.hp = max(0, target.hp - damage)
	if target.has_status("sleep") and target.is_alive():
		var wake_roll: float = RNG.randf_range(RNG_STREAM_ACTION, 0.0, 1.0)
		if wake_roll <= Balance.DEFAULTS.get("wake_chance", 0.5):
			target.clear_status("sleep")
			_append_log(tr("%s wakes up!") % target.name)
	if target.hp <= 0:
		_append_log(tr("%s is defeated.") % target.name)

func _guard(entity: BattleEntity) -> void:
	if entity == null:
		return
	entity.guard_active = true
	_append_log(tr("%s takes a defensive stance.") % entity.name)

func _roll_crit(entity: BattleEntity) -> bool:
	var chance: float = entity.get_stat("crit")
	if chance <= 0.0:
		chance = Balance.DEFAULTS.get("crit_rate", 0.05)
	return RNG.randf_range(RNG_STREAM_ACTION, 0.0, 1.0) <= chance

func _finalize_battle() -> void:
	if _encounter_resolved:
		return
	if _turn_counter >= MAX_TURNS and not _battle.is_battle_over():
		_append_log(tr("The battle ends in a stalemate after %d turns.") % MAX_TURNS)
	elif _battle.all_enemies_down():
		_append_log(tr("Victory! All enemies defeated."))
	elif _battle.all_allies_down():
		_append_log(tr("Defeat... the party has fallen."))
	_battle_result = {
		"victory": _battle.all_enemies_down(),
		"party_defeated": _battle.all_allies_down(),
		"turns": _turn_counter,
	}
	_apply_party_results(_battle.party_snapshot())
	_encounter_resolved = true
	_enter_phase(Phase.COMPLETE)

func _apply_party_results(snapshot: Array[Dictionary]) -> void:
	if _using_fallback_party:
		return
	for entry in snapshot:
		var index: int = int(entry.get("index", -1))
		if index < 0:
			continue
		var payload: Dictionary = {}
		if entry.has("hp"):
			payload["hp"] = entry["hp"]
		if entry.has("mp"):
			payload["mp"] = entry["mp"]
		if not payload.is_empty():
			Game.update_party_member(index, payload)

func _localize_skill_name(skill: Dictionary) -> String:
	var name_data: Variant = skill.get("name")
	if name_data is Dictionary:
		var dict_name: Dictionary = name_data
		if dict_name.has("ja"):
			return str(dict_name["ja"])
		if dict_name.has("en"):
			return str(dict_name["en"])
	elif name_data is String:
		return name_data
	return str(skill.get("id", "Skill"))

func _get_skill_or_default(skill_id: String) -> Dictionary:
	if skill_id == "":
		return Dictionary()
	var skill: Dictionary = Data.get_skill_by_id(skill_id)
	if skill.is_empty() and skill_id == ATTACK_SKILL_ID:
		return {
			"id": ATTACK_SKILL_ID,
			"name": {
				"en": "Attack",
				"ja": "こうげき",
			},
			"type": "skill",
			"element": "physical",
			"power": 1.0,
			"cost_mp": 0,
			"target": "enemy_single",
		}
	return skill

func _localize_item_name(item: Dictionary) -> String:
	var name_data: Variant = item.get("name")
	if name_data is Dictionary:
		var dict_name: Dictionary = name_data
		if dict_name.has("ja"):
			return str(dict_name["ja"])
		if dict_name.has("en"):
			return str(dict_name["en"])
	elif name_data is String:
		return name_data
	return str(item.get("id", "Item"))

func _select_enemy_wave(act: int) -> Array[Dictionary]:
	var dataset: Array = Data.get_dataset("enemies")
	if dataset.is_empty():
		return [_build_default_enemy("Training Dummy", 40, 0, 8, 4, 6, 4, [ATTACK_SKILL_ID])]
	var wave: Array[Dictionary] = []
	var count: int = clampi(2 + act, 1, 4)
	for i in range(count):
		var definition: Dictionary = RNG.choice(RNG_STREAM_AI, dataset)
		if definition == null:
			definition = dataset[0]
		wave.append(definition.duplicate(true))
	return wave

func _build_default_enemy(name: String, hp: int, mp: int, atk: int, def_stat: int, agi: int, matk: int, skills: Array[String]) -> Dictionary:
	return {
		"id": "training_dummy",
		"name": name,
		"hp": hp,
		"mp": mp,
		"atk": atk,
		"def": def_stat,
		"agi": agi,
		"matk": matk,
		"skills": skills,
	}

class BattleCommand:
	const TYPE_SKILL: String = "skill"
	const TYPE_GUARD: String = "guard"
	const TYPE_ITEM: String = "item"

	var actor: BattleEntity
	var command_type: String
	var skill: Dictionary = {}
	var targets: Array[BattleEntity] = []
	var item_id: String = ""
	var item_effect: String = ""
	var item_slot: int = -1
	var item_payload: Dictionary = {}

	func _init(actor_ref: BattleEntity, command_type_ref: String) -> void:
		actor = actor_ref
		command_type = command_type_ref

class BattleController:
	var allies: Array[BattleEntity] = []
	var enemies: Array[BattleEntity] = []
	var max_frontline: int

	func _init(party_payload: Array[Dictionary], enemy_payload: Array[Dictionary], frontline_size: int) -> void:
		max_frontline = frontline_size
		_build_allies(party_payload)
		_build_enemies(enemy_payload)

	func _build_allies(party_payload: Array[Dictionary]) -> void:
		for i in range(party_payload.size()):
			var member: Dictionary = party_payload[i]
			var frontline: bool = i < max_frontline
			var entity := BattleEntity.new(member, false, i, frontline)
			allies.append(entity)

	func _build_enemies(enemy_payload: Array[Dictionary]) -> void:
		var capped_payload: Array[Dictionary] = []
		for i in range(enemy_payload.size()):
			if i >= 8:
				break
			capped_payload.append(enemy_payload[i].duplicate(true))
		if capped_payload.is_empty():
			capped_payload.append({
				"id": "fallback_enemy",
				"name": "Training Dummy",
				"hp": 40,
				"mp": 0,
				"atk": 8,
				"def": 4,
				"agi": 6,
				"matk": 4,
				"skills": [ATTACK_SKILL_ID],
			})
		for definition in capped_payload:
			var entity := BattleEntity.new(definition, true, -1, true)
			enemies.append(entity)

	func get_all_allies() -> Array[BattleEntity]:
		return allies

	func get_all_enemies() -> Array[BattleEntity]:
		return enemies

	func get_frontline_allies() -> Array[BattleEntity]:
		var result: Array[BattleEntity] = []
		for ally in allies:
			if ally.frontline and ally.is_alive():
				result.append(ally)
		return result

	func get_live_frontline_allies() -> Array[BattleEntity]:
		return get_frontline_allies()

	func get_live_allies() -> Array[BattleEntity]:
		var result: Array[BattleEntity] = []
		for ally in allies:
			if ally.is_alive():
				result.append(ally)
		return result

	func get_live_enemies() -> Array[BattleEntity]:
		var result: Array[BattleEntity] = []
		for enemy in enemies:
			if enemy.is_alive():
				result.append(enemy)
		return result

	func refresh_frontline() -> Array[BattleEntity]:
		var current_front: Array[BattleEntity] = []
		for ally in allies:
			if ally.frontline and not ally.is_alive():
				ally.frontline = false
			if ally.frontline and ally.is_alive():
				current_front.append(ally)
		if current_front.size() >= max_frontline:
			return []
		var moved: Array[BattleEntity] = []
		for ally in allies:
			if current_front.size() >= max_frontline:
				break
			if ally.frontline or not ally.is_alive():
				continue
			ally.frontline = true
			current_front.append(ally)
			moved.append(ally)
		return moved

	func swap_allies(first: BattleEntity, second: BattleEntity) -> bool:
		if first == null or second == null or first == second:
			return false
		if first.frontline == second.frontline:
			return false
		var first_front: bool = first.frontline
		first.frontline = second.frontline
		second.frontline = first_front
		return true

	func build_turn_order() -> Array[BattleEntity]:
		var participants: Array[BattleEntity] = []
		for ally in allies:
			if ally.frontline and ally.is_alive():
				ally.roll_initiative()
				participants.append(ally)
		for enemy in enemies:
			if enemy.is_alive():
				enemy.roll_initiative()
				participants.append(enemy)
		participants.sort_custom(Callable(self, "_sort_by_initiative"))
		return participants

	func _sort_by_initiative(a: BattleEntity, b: BattleEntity) -> bool:
		if a.initiative == b.initiative:
			return a.get_stat("agi") > b.get_stat("agi")
		return a.initiative > b.initiative

	func end_of_turn(log: Array[String]) -> void:
		for entity in _combined_entities():
			if not entity.is_alive():
				continue
			if entity.has_status("poison"):
				var poison_damage: int = max(1, int(floor(entity.max_hp * 0.05)))
				log.append("Poison deals %d damage to %s." % [poison_damage, entity.name])
				entity.hp = max(0, entity.hp - poison_damage)
				entity.tick_status("poison")
				if entity.hp <= 0:
					log.append("%s succumbs to poison." % entity.name)
			if entity.has_status("silence"):
				entity.tick_status("silence")

	func party_snapshot() -> Array[Dictionary]:
		var snapshot: Array[Dictionary] = []
		for entity in allies:
			snapshot.append({
				"index": entity.index,
				"hp": entity.hp,
				"mp": entity.mp,
			})
		return snapshot

	func _combined_entities() -> Array[BattleEntity]:
		var combined: Array[BattleEntity] = []
		combined.append_array(allies)
		combined.append_array(enemies)
		return combined

	func is_battle_over() -> bool:
		return all_allies_down() or all_enemies_down()

	func all_allies_down() -> bool:
		for ally in allies:
			if ally.is_alive():
				return false
		return true

	func all_enemies_down() -> bool:
		for enemy in enemies:
			if enemy.is_alive():
				return false
		return true

class BattleEntity:
	var index: int
	var name: String
	var is_enemy: bool
	var frontline: bool
	var hp: int
	var max_hp: int
	var mp: int
	var max_mp: int
	var stats: Dictionary
	var skills: Array[String] = []
	var statuses: Dictionary = {}
	var guard_active: bool = false
	var initiative: int = 0

	func _init(payload: Dictionary, enemy: bool, party_index: int, frontline_member: bool) -> void:
		index = party_index
		is_enemy = enemy
		frontline = frontline_member
		name = str(payload.get("name", payload.get("id", "Unknown")))
		max_hp = int(payload.get("max_hp", payload.get("hp", 1)))
		hp = clampi(int(payload.get("hp", max_hp)), 0, max_hp)
		max_mp = int(payload.get("max_mp", payload.get("mp", 0)))
		mp = clampi(int(payload.get("mp", max_mp)), 0, max_mp)
		stats = {
			"atk": float(payload.get("atk", 0)),
			"def": float(payload.get("def", 0)),
			"agi": float(payload.get("agi", 0)),
			"matk": float(payload.get("matk", 0)),
			"rec": float(payload.get("rec", 0)),
			"crit": float(payload.get("crit", Balance.DEFAULTS.get("crit_rate", 0.05))),
			"critx": float(payload.get("critx", Balance.DEFAULTS.get("crit_mul", 1.5))),
		}
		skills = []
		for entry in payload.get("skills", []):
			skills.append(str(entry))
		if skills.is_empty():
			skills.append(ATTACK_SKILL_ID)
		statuses = {}
		guard_active = false

	func is_alive() -> bool:
		return hp > 0

	func get_stat(stat: StringName) -> float:
		return float(stats.get(stat, 0.0))

	func has_status(status: StringName) -> bool:
		return statuses.has(status)

	func clear_status(status: StringName) -> void:
		statuses.erase(status)

	func add_status(status: StringName, duration: int) -> void:
		statuses[status] = {
			"remaining": duration,
		}

	func tick_status(status: StringName) -> void:
		if not statuses.has(status):
			return
		var entry: Dictionary = statuses[status]
		entry["remaining"] = int(entry.get("remaining", 1)) - 1
		if entry["remaining"] <= 0:
			statuses.erase(status)
		else:
			statuses[status] = entry

	func roll_initiative() -> void:
		initiative = int(get_stat("agi")) + RNG.randi_range(RNG_STREAM_ACTION, 0, 10)

	func heal_hp(amount: int) -> int:
		if amount <= 0:
			return 0
		var before: int = hp
		hp = clampi(hp + amount, 0, max_hp)
		return hp - before

	func restore_mp(amount: int) -> int:
		if amount <= 0:
			return 0
		var before: int = mp
		mp = clampi(mp + amount, 0, max_mp)
		return mp - before
