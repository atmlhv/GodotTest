extends Control

@onready var label: Label = $Label

func _ready() -> void:
    label.text = _build_summary()

func _build_summary() -> String:
    var drop_skill := Balance.DEFAULTS["p_skill_drop"] * 100.0
    var drop_item := Balance.DEFAULTS["p_item_drop"] * 100.0
    return "Reward placeholder\nSkill chance %.0f%%\nItem chance %.0f%%" % [drop_skill, drop_item]
