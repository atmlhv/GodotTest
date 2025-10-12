extends Control

var shop_data: Dictionary = {}
var awaiting_item_replace: bool = false
var pending_item_index: int = -1

@onready var info_label: Label = $VBox/InfoLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var skill_list: ItemList = $VBox/SkillsSection/SkillList
@onready var skill_target: OptionButton = $VBox/SkillsSection/SkillTarget
@onready var skill_buy: Button = $VBox/SkillsSection/SkillBuy
@onready var equipment_list: ItemList = $VBox/EquipmentSection/EquipmentList
@onready var equipment_target: OptionButton = $VBox/EquipmentSection/EquipmentTarget
@onready var equipment_buy: Button = $VBox/EquipmentSection/EquipmentBuy
@onready var item_list: ItemList = $VBox/ItemsSection/ItemList
@onready var item_buy: Button = $VBox/ItemsSection/ItemBuy
@onready var item_status: Label = $VBox/ItemsSection/ItemStatus
@onready var replace_row: HBoxContainer = $VBox/ItemsSection/ReplaceRow
@onready var replace_select: OptionButton = $VBox/ItemsSection/ReplaceRow/ReplaceSelect
@onready var replace_confirm: Button = $VBox/ItemsSection/ReplaceRow/ReplaceConfirm
@onready var replace_cancel: Button = $VBox/ItemsSection/ReplaceRow/ReplaceCancel
@onready var return_button: Button = $VBox/ReturnButton

func _ready() -> void:
    Game.ensure_shop_inventory()
    _populate_party_targets()
    skill_buy.pressed.connect(_on_skill_buy_pressed)
    equipment_buy.pressed.connect(_on_equipment_buy_pressed)
    item_buy.pressed.connect(_on_item_buy_pressed)
    replace_confirm.pressed.connect(_on_replace_confirm_pressed)
    replace_cancel.pressed.connect(_on_replace_cancel_pressed)
    return_button.pressed.connect(_on_leave_pressed)
    _refresh_shop()
    status_label.text = "Select goods to purchase."

func _populate_party_targets() -> void:
    var party: Array[Dictionary] = Game.get_party_overview()
    skill_target.clear()
    equipment_target.clear()
    for index in range(party.size()):
        var member: Dictionary = party[index]
        var name: String = str(member.get("name", "???"))
        skill_target.add_item(name, index)
        equipment_target.add_item(name, index)
    if skill_target.item_count > 0:
        skill_target.select(0)
        skill_target.disabled = false
    else:
        skill_target.disabled = true
    if equipment_target.item_count > 0:
        equipment_target.select(0)
        equipment_target.disabled = false
    else:
        equipment_target.disabled = true

func _refresh_shop() -> void:
    shop_data = Game.get_shop_inventory()
    info_label.text = _build_header_text()
    _refresh_skill_section()
    _refresh_equipment_section()
    _refresh_item_section()

func _build_header_text() -> String:
    var act: int = Game.get_current_act()
    var ascension: int = Game.get_ascension_level()
    return "Shop - Act %d (Ascension %d)" % [act, ascension]

func _refresh_skill_section() -> void:
    skill_list.clear()
    var skills: Array = shop_data.get("skills", [])
    var any_available: bool = false
    for index in range(skills.size()):
        var entry: Dictionary = skills[index]
        var name: String = str(entry.get("display_name", entry.get("id", "???")))
        var price: int = int(entry.get("price", 0))
        var sold: bool = bool(entry.get("sold", false))
        var line: String = "%s - %dG" % [name, price]
        if sold:
            line += " (Sold)"
        else:
            any_available = true
        skill_list.add_item(line)
        skill_list.set_item_disabled(index, sold)
    if skill_list.item_count > 0:
        skill_list.select(0)
    skill_buy.disabled = not any_available
    skill_target.disabled = skill_target.item_count == 0 or not any_available

func _refresh_equipment_section() -> void:
    equipment_list.clear()
    var equipment: Array = shop_data.get("equipment", [])
    var any_available: bool = false
    for index in range(equipment.size()):
        var entry: Dictionary = equipment[index]
        var name: String = str(entry.get("display_name", entry.get("id", "???")))
        var slot: String = str(entry.get("slot", ""))
        var price: int = int(entry.get("price", 0))
        var sold: bool = bool(entry.get("sold", false))
        var label: String = "%s [%s] - %dG" % [name, slot.capitalize(), price]
        if sold:
            label += " (Sold)"
        else:
            any_available = true
        equipment_list.add_item(label)
        equipment_list.set_item_disabled(index, sold)
    if equipment_list.item_count > 0:
        equipment_list.select(0)
    equipment_buy.disabled = not any_available
    equipment_target.disabled = equipment_target.item_count == 0 or not any_available

func _refresh_item_section() -> void:
    item_list.clear()
    var items: Array = shop_data.get("items", [])
    var any_available: bool = false
    for index in range(items.size()):
        var entry: Dictionary = items[index]
        var name: String = str(entry.get("display_name", entry.get("id", "???")))
        var quantity: int = int(entry.get("quantity", 1))
        var price: int = int(entry.get("price", 0))
        var sold: bool = bool(entry.get("sold", false))
        var label: String = "%s x%d - %dG" % [name, quantity, price]
        if sold:
            label += " (Sold)"
        else:
            any_available = true
        item_list.add_item(label)
        item_list.set_item_disabled(index, sold)
    if item_list.item_count > 0:
        item_list.select(0)
    item_buy.disabled = not any_available
    if awaiting_item_replace:
        _refresh_replace_options()
    replace_row.visible = awaiting_item_replace

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

func _on_skill_buy_pressed() -> void:
    var selection: PackedInt32Array = skill_list.get_selected_items()
    if selection.is_empty():
        status_label.text = "Select a skill to purchase."
        return
    var index: int = selection[0]
    var entry: Dictionary = _shop_entry(shop_data.get("skills", []), index)
    if entry.is_empty():
        status_label.text = "Skill unavailable."
        return
    if bool(entry.get("sold", false)):
        status_label.text = "Skill already purchased."
        return
    var member_index: int = _selected_party_member(skill_target)
    if member_index < 0:
        status_label.text = "Select a party member."
        return
    var price: int = int(entry.get("price", 0))
    if Game.get_gold() < price:
        status_label.text = "Not enough gold."
        return
    if Game.purchase_shop_skill(index, member_index):
        status_label.text = "Purchased %s." % entry.get("display_name", entry.get("id", "skill"))
        awaiting_item_replace = false
        pending_item_index = -1
        _populate_party_targets()
        _refresh_shop()
    else:
        status_label.text = "Unable to purchase skill."

func _on_equipment_buy_pressed() -> void:
    var selection: PackedInt32Array = equipment_list.get_selected_items()
    if selection.is_empty():
        status_label.text = "Select equipment to purchase."
        return
    var index: int = selection[0]
    var entry: Dictionary = _shop_entry(shop_data.get("equipment", []), index)
    if entry.is_empty():
        status_label.text = "Equipment unavailable."
        return
    if bool(entry.get("sold", false)):
        status_label.text = "Equipment already purchased."
        return
    var member_index: int = _selected_party_member(equipment_target)
    if member_index < 0:
        status_label.text = "Select a party member."
        return
    var price: int = int(entry.get("price", 0))
    if Game.get_gold() < price:
        status_label.text = "Not enough gold."
        return
    if Game.purchase_shop_equipment(index, member_index):
        status_label.text = "Purchased %s." % entry.get("display_name", entry.get("id", "gear"))
        awaiting_item_replace = false
        pending_item_index = -1
        _populate_party_targets()
        _refresh_shop()
    else:
        status_label.text = "Unable to purchase equipment."

func _on_item_buy_pressed() -> void:
    var selection: PackedInt32Array = item_list.get_selected_items()
    if selection.is_empty():
        item_status.text = "Select an item to purchase."
        return
    var index: int = selection[0]
    var entry: Dictionary = _shop_entry(shop_data.get("items", []), index)
    if entry.is_empty():
        item_status.text = "Item unavailable."
        return
    if bool(entry.get("sold", false)):
        item_status.text = "Item already purchased."
        return
    var price: int = int(entry.get("price", 0))
    if Game.get_gold() < price:
        item_status.text = "Not enough gold."
        return
    var item_id: String = str(entry.get("id", ""))
    if not Game.can_add_item_to_inventory(item_id):
        awaiting_item_replace = true
        pending_item_index = index
        _refresh_item_section()
        item_status.text = "Inventory full. Select a slot to replace or cancel."
        return
    if Game.purchase_shop_item(index):
        item_status.text = "Purchased %s." % entry.get("display_name", entry.get("id", "item"))
        awaiting_item_replace = false
        pending_item_index = -1
        _refresh_shop()
    else:
        item_status.text = "Unable to purchase item."

func _on_replace_confirm_pressed() -> void:
    if not awaiting_item_replace or pending_item_index < 0:
        return
    if replace_select.item_count == 0:
        item_status.text = "No slots to replace."
        return
    var selected_id: int = replace_select.get_selected_id()
    if selected_id < 0:
        selected_id = replace_select.get_selected()
    if selected_id < 0:
        item_status.text = "Select a slot to replace."
        return
    if Game.purchase_shop_item_with_replacement(pending_item_index, selected_id):
        var entry: Dictionary = _shop_entry(shop_data.get("items", []), pending_item_index)
        item_status.text = "Purchased %s." % entry.get("display_name", entry.get("id", "item"))
        awaiting_item_replace = false
        pending_item_index = -1
        _refresh_shop()
    else:
        item_status.text = "Unable to replace item."

func _on_replace_cancel_pressed() -> void:
    awaiting_item_replace = false
    pending_item_index = -1
    replace_row.visible = false
    item_status.text = "Purchase cancelled."

func _on_leave_pressed() -> void:
    Game.finish_current_node()

func _shop_entry(array: Variant, index: int) -> Dictionary:
    if array is Array and index >= 0 and index < (array as Array).size():
        var entry_variant: Variant = (array as Array)[index]
        if entry_variant is Dictionary:
            return (entry_variant as Dictionary)
    return Dictionary()

func _selected_party_member(selector: OptionButton) -> int:
    if selector.item_count == 0:
        return -1
    var selected_id: int = selector.get_selected_id()
    if selected_id >= 0:
        return selected_id
    return selector.get_selected()
