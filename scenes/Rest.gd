extends Control

@onready var label: Label = $Label

func _ready() -> void:
    label.text = _describe_options()

func _describe_options() -> String:
    var modifiers: Dictionary = Data.get_ascension_level(Game.get_ascension_level())
    var rest_scale: float = float(modifiers.get("rest_heal_scale", 1.0))
    var heal_percent: float = 30.0 * rest_scale
    return "Rest placeholder\nHeal %.0f%% HP or MP\nForge once" % heal_percent
