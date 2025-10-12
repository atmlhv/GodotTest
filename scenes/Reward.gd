extends Control

var reward_data: Dictionary = {}
var awaiting_replace_choice: bool = false
var _equipment_list_default_focus_mode: int
var _equipment_list_default_mouse_filter: int
var _skill_list_default_focus_mode: int
var _skill_list_default_mouse_filter: int

@onready var info_label: Label = $VBox/InfoLabel
@onready var gold_label: Label = $VBox/GoldSection/GoldLabel
@onready var gold_button: Button = $VBox/GoldSection/ClaimGoldButton
@onready var equipment_label: Label = $VBox/EquipmentSection/SectionLabel
@onready var equipment_list: ItemList = $VBox/EquipmentSection/EquipmentList
@onready var equipment_target: OptionButton = $VBox/EquipmentSection/TargetSelect
@onready var equipment_button: Button = $VBox/EquipmentSection/EquipButton
@onready var skill_label: Label = $VBox/SkillSection/SectionLabel
@onready var skill_list: ItemList = $VBox/SkillSection/SkillList
@onready var skill_target: OptionButton = $VBox/SkillSection/TargetSelect
@onready var skill_button: Button = $VBox/SkillSection/LearnButton
@onready var item_label: Label = $VBox/ItemSection/ItemLabel
@onready var item_status: Label = $VBox/ItemSection/ItemStatus
@onready var claim_item_button: Button = $VBox/ItemSection/ClaimButton
@onready var replace_row: HBoxContainer = $VBox/ItemSection/ReplaceRow
@onready var replace_select: OptionButton = $VBox/ItemSection/ReplaceRow/ReplaceSelect
@onready var replace_button: Button = $VBox/ItemSection/ReplaceRow/ReplaceButton
@onready var discard_button: Button = $VBox/ItemSection/ReplaceRow/DiscardButton
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
    reward_data = Game.ensure_reward_for_active_node()
    _equipment_list_default_focus_mode = equipment_list.focus_mode
    _equipment_list_default_mouse_filter = equipment_list.mouse_filter
    _skill_list_default_focus_mode = skill_list.focus_mode
    _skill_list_default_mouse_filter = skill_list.mouse_filter
    _populate_party_targets()
    gold_button.pressed.connect(_on_claim_gold_pressed)
    equipment_button.pressed.connect(_on_equip_pressed)
    skill_button.pressed.connect(_on_learn_pressed)
    claim_item_button.pressed.connect(_on_claim_item_pressed)
    replace_button.pressed.connect(_on_replace_item_pressed)
    discard_button.pressed.connect(_on_discard_item_pressed)
    continue_button.pressed.connect(_on_continue_pressed)
    _sync_reward_state()

func _sync_reward_state() -> void:
    reward_data = Game.get_pending_reward()
    info_label.text = _build_header_text()
    _refresh_gold_section()
    _refresh_equipment_section()
    _refresh_skill_section()
    _refresh_item_section()
    continue_button.disabled = not _is_reward_complete()

func _build_header_text() -> String:
    if reward_data.is_empty():
        return "Rewards"
    var act: int = Game.get_current_act()
    var node_type: String = str(reward_data.get("node_type", "battle"))
    var display_type: String = node_type.capitalize()
    return "Act %d %s Rewards" % [act, display_type]

func _populate_party_targets() -> void:
    var party: Array[Dictionary] = Game.get_party_overview()
    equipment_target.clear()
    skill_target.clear()
    for index in range(party.size()):
        var member: Dictionary = party[index]
        var name: String = str(member.get("name", "???"))
        equipment_target.add_item(name, index)
        skill_target.add_item(name, index)
    if equipment_target.item_count > 0:
        equipment_target.select(0)
    else:
        equipment_target.disabled = true
    if skill_target.item_count > 0:
        skill_target.select(0)
    else:
        skill_target.disabled = true

func _refresh_gold_section() -> void:
    var amount: int = int(reward_data.get("gold", 0))
    var claimed: bool = reward_data.get("claimed_gold", false)
    if amount <= 0:
        gold_label.text = "No gold reward"
        gold_button.disabled = true
        gold_button.text = "N/A"
        return
    var status: String = "Claimed" if claimed else "Unclaimed"
    gold_label.text = "Gold: %d (%s)" % [amount, status]
    gold_button.disabled = claimed
    gold_button.text = "Collected" if claimed else "Take Gold"

func _refresh_equipment_section() -> void:
    var choices: Array = reward_data.get("equipment_choices", [])
    var claimed: bool = reward_data.get("claimed_equipment", false)
    equipment_list.clear()
    if choices.is_empty():
        equipment_label.text = "No equipment reward"
        _set_equipment_list_enabled(false)
        equipment_button.disabled = true
        equipment_target.disabled = true
        return
    equipment_label.text = "Select one piece of equipment"
    for index in range(choices.size()):
        var entry: Dictionary = choices[index]
        var name: String = str(entry.get("display_name", entry.get("id", "???")))
        var slot: String = str(entry.get("slot", ""))
        var text: String = name if slot == "" else "%s [%s]" % [name, slot.capitalize()]
        equipment_list.add_item(text)
    if not claimed:
        _set_equipment_list_enabled(true)
        equipment_button.disabled = false
        equipment_target.disabled = equipment_target.item_count == 0
        if equipment_list.item_count > 0:
            equipment_list.select(0)
    else:
        equipment_label.text = "Equipment reward claimed"
        _set_equipment_list_enabled(false)
        equipment_button.disabled = true
        equipment_target.disabled = true

func _refresh_skill_section() -> void:
    var choices: Array = reward_data.get("skill_choices", [])
    var claimed: bool = reward_data.get("claimed_skill", false)
    skill_list.clear()
    if choices.is_empty():
        skill_label.text = "No skill drop"
        _set_skill_list_enabled(false)
        skill_button.disabled = true
        skill_target.disabled = true
        return
    skill_label.text = "Choose a skill to learn"
    for index in range(choices.size()):
        var entry: Dictionary = choices[index]
        var name: String = str(entry.get("display_name", entry.get("id", "???")))
        skill_list.add_item(name)
    if not claimed:
        _set_skill_list_enabled(true)
        skill_button.disabled = false
        skill_target.disabled = skill_target.item_count == 0
        if skill_list.item_count > 0:
            skill_list.select(0)
    else:
        skill_label.text = "Skill reward claimed"
        _set_skill_list_enabled(false)
        skill_button.disabled = true
        skill_target.disabled = true

func _refresh_item_section() -> void:
    var reward_item: Dictionary = reward_data.get("item_reward", Dictionary())
    var claimed: bool = reward_data.get("claimed_item", false)
    if reward_item.is_empty():
        item_label.text = "No item drop"
        item_status.text = ""
        claim_item_button.disabled = true
        claim_item_button.text = "N/A"
        replace_row.visible = false
        awaiting_replace_choice = false
        return
    var name: String = str(reward_item.get("display_name", reward_item.get("id", "???")))
    var quantity: int = int(reward_item.get("quantity", 1))
    item_label.text = "Item: %s x%d" % [name, quantity]
    if claimed:
        item_status.text = "Item resolved"
        claim_item_button.disabled = true
        claim_item_button.text = "Resolved"
        replace_row.visible = false
        awaiting_replace_choice = false
        return
    claim_item_button.disabled = false
    claim_item_button.text = "Add to inventory"
    replace_row.visible = awaiting_replace_choice
    if awaiting_replace_choice:
        item_status.text = "Inventory full. Select a slot to replace or discard."
        _refresh_replace_options()
    else:
        item_status.text = ""

func _refresh_replace_options() -> void:
    replace_select.clear()
    var inventory: Array[Dictionary] = Game.get_inventory()
    for index in range(inventory.size()):
        var entry: Dictionary = inventory[index]
        var description: String = _describe_inventory_entry(entry)
        replace_select.add_item(description, index)
    if replace_select.item_count > 0:
        replace_select.select(0)

func _describe_inventory_entry(entry: Dictionary) -> String:
    var item_id: String = str(entry.get("id", ""))
    var quantity: int = int(entry.get("quantity", 1))
    var data: Dictionary = Data.get_item_by_id(item_id)
    var name: String = item_id
    if not data.is_empty():
        var raw_name: Variant = data.get("name")
        if raw_name is Dictionary:
            var dict_name: Dictionary = raw_name
            if dict_name.has("ja"):
                name = str(dict_name["ja"])
            elif dict_name.has("en"):
                name = str(dict_name["en"])
        elif raw_name is String:
            name = raw_name
    return "%s x%d" % [name, quantity]

func _is_reward_complete() -> bool:
    if reward_data.is_empty():
        return true
    var claimed_gold: bool = bool(reward_data.get("claimed_gold", true))
    var claimed_equipment: bool = bool(reward_data.get("claimed_equipment", true))
    var claimed_skill: bool = bool(reward_data.get("claimed_skill", true))
    var claimed_item: bool = bool(reward_data.get("claimed_item", true))
    return claimed_gold and claimed_equipment and claimed_skill and claimed_item

func _on_claim_gold_pressed() -> void:
    Game.claim_reward_gold()
    _sync_reward_state()

func _on_equip_pressed() -> void:
    var selection: PackedInt32Array = equipment_list.get_selected_items()
    if selection.is_empty():
        equipment_label.text = "Select equipment to claim"
        return
    var member_index: int = _selected_party_member(equipment_target)
    if member_index < 0:
        equipment_label.text = "Select a party member"
        return
    var success: bool = Game.claim_reward_equipment(selection[0], member_index)
    if not success:
        equipment_label.text = "Unable to assign equipment"
        return
    awaiting_replace_choice = false
    _sync_reward_state()

func _on_learn_pressed() -> void:
    var selection: PackedInt32Array = skill_list.get_selected_items()
    if selection.is_empty():
        skill_label.text = "Select a skill"
        return
    var member_index: int = _selected_party_member(skill_target)
    if member_index < 0:
        skill_label.text = "Select a party member"
        return
    var success: bool = Game.claim_reward_skill(selection[0], member_index)
    if not success:
        skill_label.text = "Unable to learn skill"
        return
    awaiting_replace_choice = false
    _sync_reward_state()

func _on_claim_item_pressed() -> void:
    if Game.try_claim_reward_item():
        awaiting_replace_choice = false
        _sync_reward_state()
    else:
        awaiting_replace_choice = true
        _sync_reward_state()

func _on_replace_item_pressed() -> void:
    if not awaiting_replace_choice:
        return
    var slot_index: int = _selected_replace_slot()
    if slot_index < 0:
        item_status.text = "Select a slot to replace"
        return
    if Game.replace_reward_item(slot_index):
        awaiting_replace_choice = false
        _sync_reward_state()
    else:
        item_status.text = "Replacement failed"

func _on_discard_item_pressed() -> void:
    Game.discard_reward_item()
    awaiting_replace_choice = false
    _sync_reward_state()

func _on_continue_pressed() -> void:
    if not _is_reward_complete():
        return
    Game.finish_current_node()

func _selected_party_member(selector: OptionButton) -> int:
    if selector.item_count == 0:
        return -1
    var selected_id: int = selector.get_selected_id()
    if selected_id >= 0:
        return selected_id
    return selector.get_selected()

func _selected_replace_slot() -> int:
    if replace_select.item_count == 0:
        return -1
    var selected_id: int = replace_select.get_selected_id()
    if selected_id >= 0:
        return selected_id
    return replace_select.get_selected()

func _set_equipment_list_enabled(enabled: bool) -> void:
    _set_item_list_enabled(equipment_list, enabled, _equipment_list_default_focus_mode, _equipment_list_default_mouse_filter)

func _set_skill_list_enabled(enabled: bool) -> void:
    _set_item_list_enabled(skill_list, enabled, _skill_list_default_focus_mode, _skill_list_default_mouse_filter)

func _set_item_list_enabled(list: ItemList, enabled: bool, default_focus_mode: int, default_mouse_filter: int) -> void:
    list.focus_mode = default_focus_mode if enabled else Control.FOCUS_NONE
    list.mouse_filter = default_mouse_filter if enabled else Control.MOUSE_FILTER_IGNORE
