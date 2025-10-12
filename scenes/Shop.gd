extends Control

@onready var info_label: Label = $VBox/InfoLabel
@onready var return_button: Button = $VBox/ReturnButton

func _ready() -> void:
    info_label.text = _build_placeholder()
    return_button.pressed.connect(_on_leave_pressed)

func _build_placeholder() -> String:
    var ascension: int = Game.get_ascension_level()
    var modifiers: Dictionary = Data.get_ascension_level(ascension)
    var cost_scale: float = float(modifiers.get("shop_cost_scale", 1.0))
    return "Shop placeholder\nCost scale x%.2f" % cost_scale

func _on_leave_pressed() -> void:
    Game.finish_current_node()
