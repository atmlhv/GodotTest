extends Control

@onready var label: Label = $Label

func _ready() -> void:
    label.text = _build_placeholder()

func _build_placeholder() -> String:
    var ascension := Game.get_ascension_level()
    var modifiers := Data.get_ascension_level(ascension)
    var cost_scale := modifiers.get("shop_cost_scale", 1.0)
    return "Shop placeholder\nCost scale x%.2f" % cost_scale
