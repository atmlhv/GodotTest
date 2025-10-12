extends Control

@onready var info_label: Label = $VBox/InfoLabel
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
    info_label.text = _build_summary()
    continue_button.pressed.connect(_on_continue_pressed)

func _build_summary() -> String:
    var equipment_data: Variant = Data.get_dataset("equipment")
    var pool: Array = equipment_data if equipment_data is Array else []
    if pool.is_empty():
        return "Reward placeholder\nNo equipment data available"
    var choices: Array[String] = []
    var used_indices: Array[int] = []
    var limit: int = int(min(3, pool.size()))
    while choices.size() < limit:
        var index: int = RNG.randi_range("loot", 0, pool.size() - 1)
        if used_indices.has(index):
            continue
        used_indices.append(index)
        var entry_variant: Variant = pool[index]
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant
        var rarity: String = entry.get("rarity", "common")
        var name: String = entry.get("name", entry.get("id", "???"))
        choices.append("%s (%s)" % [name, rarity.capitalize()])
    if choices.is_empty():
        return "Reward placeholder\nNo valid drops"
    var drop_skill: float = Balance.DEFAULTS["p_skill_drop"] * 100.0
    var drop_item: float = Balance.DEFAULTS["p_item_drop"] * 100.0
    var header: String = "Skill %.0f%% | Item %.0f%%" % [drop_skill, drop_item]
    return header + "\n\nEquipment choices:\n- " + "\n- ".join(choices)

func _on_continue_pressed() -> void:
    Game.finish_current_node()
