extends Control

@onready var label: Label = $Label

func _ready() -> void:
    label.text = _generate_preview_text()

func _generate_preview_text() -> String:
    var act := Game.get_current_act()
    var ascension := Game.get_ascension_level()
    return "Act %d | Ascension %d\n(Map system placeholder)" % [act, ascension]
