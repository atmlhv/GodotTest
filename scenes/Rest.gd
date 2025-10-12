extends Control

@onready var info_label: Label = $VBox/InfoLabel
@onready var result_label: Label = $VBox/ResultLabel
@onready var heal_hp_button: Button = $VBox/HealHPButton
@onready var heal_mp_button: Button = $VBox/HealMPButton
@onready var smith_button: Button = $VBox/SmithButton
@onready var smith_container: VBoxContainer = $VBox/SmithContainer
@onready var smith_select: OptionButton = $VBox/SmithContainer/SmithSelect
@onready var smith_confirm: Button = $VBox/SmithContainer/SmithButtons/SmithConfirm
@onready var smith_cancel: Button = $VBox/SmithContainer/SmithButtons/SmithCancel

var _smith_candidates: Array[Dictionary] = []

func _ready() -> void:
    info_label.text = _describe_options()
    result_label.text = ""
    heal_hp_button.pressed.connect(_on_heal_hp_pressed)
    heal_mp_button.pressed.connect(_on_heal_mp_pressed)
    smith_button.pressed.connect(_on_smith_pressed)
    smith_confirm.pressed.connect(_on_smith_confirm_pressed)
    smith_cancel.pressed.connect(_on_smith_cancel_pressed)

func _describe_options() -> String:
    var heal_percent: float = Game.get_rest_heal_percentage()
    return "Campfire\nHeal %.0f%% HP or MP for all allies\nForge one piece of gear (+10%% stats)" % heal_percent

func _on_heal_hp_pressed() -> void:
    var percent: float = Game.get_rest_heal_percentage()
    var outcome: Dictionary = Game.rest_heal_party_hp(percent)
    var healed: int = int(outcome.get("total_healed", 0))
    result_label.text = "Recovered %d total HP." % healed
    Game.finish_current_node()

func _on_heal_mp_pressed() -> void:
    var percent: float = Game.get_rest_heal_percentage()
    var outcome: Dictionary = Game.rest_restore_party_mp(percent)
    var restored: int = int(outcome.get("total_restored", 0))
    result_label.text = "Recovered %d total MP." % restored
    Game.finish_current_node()

func _on_smith_pressed() -> void:
    _smith_candidates = Game.get_smith_candidates()
    if _smith_candidates.is_empty():
        result_label.text = "No equipment eligible for upgrade."
        smith_container.visible = false
        return
    _populate_smith_select()
    smith_container.visible = true
    result_label.text = "Select equipment to upgrade."

func _populate_smith_select() -> void:
    smith_select.clear()
    for index in range(_smith_candidates.size()):
        var entry: Dictionary = _smith_candidates[index]
        var member_name: String = str(entry.get("member_name", "???"))
        var slot: String = str(entry.get("slot", ""))
        var item_name: String = str(entry.get("item_name", entry.get("item_id", "")))
        var label: String = "%s - %s (%s)" % [member_name, slot.capitalize(), item_name]
        smith_select.add_item(label, index)
    if smith_select.item_count > 0:
        smith_select.select(0)

func _on_smith_confirm_pressed() -> void:
    if smith_select.item_count == 0:
        result_label.text = "No selection available."
        return
    var selected_id: int = smith_select.get_selected_id()
    if selected_id < 0:
        selected_id = smith_select.get_selected()
    if selected_id < 0 or selected_id >= _smith_candidates.size():
        result_label.text = "Select equipment to upgrade."
        return
    var candidate: Dictionary = _smith_candidates[selected_id]
    var member_index: int = int(candidate.get("member_index", -1))
    var slot: String = str(candidate.get("slot", ""))
    var outcome: Dictionary = Game.rest_upgrade_equipment(member_index, slot)
    if not bool(outcome.get("success", false)):
        result_label.text = str(outcome.get("error", "Upgrade failed."))
        return
    var member_name: String = str(outcome.get("member_name", "???"))
    var item_name: String = str(outcome.get("item_name", outcome.get("item_id", "")))
    result_label.text = "%s's %s was reforged." % [member_name, item_name]
    smith_container.visible = false
    Game.finish_current_node()

func _on_smith_cancel_pressed() -> void:
    smith_container.visible = false
    result_label.text = "Forge cancelled."
