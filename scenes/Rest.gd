extends Control

@onready var info_label: Label = $VBox/InfoLabel
@onready var heal_hp_button: Button = $VBox/HealHPButton
@onready var heal_mp_button: Button = $VBox/HealMPButton
@onready var smith_button: Button = $VBox/SmithButton

func _ready() -> void:
    info_label.text = _describe_options()
    heal_hp_button.pressed.connect(_on_option_pressed.bind("hp"))
    heal_mp_button.pressed.connect(_on_option_pressed.bind("mp"))
    smith_button.pressed.connect(_on_option_pressed.bind("smith"))

func _describe_options() -> String:
    var modifiers: Dictionary = Data.get_ascension_level(Game.get_ascension_level())
    var rest_scale: float = float(modifiers.get("rest_heal_scale", 1.0))
    var heal_percent: float = 30.0 * rest_scale
    return "Rest placeholder\nHeal %.0f%% HP or MP\nForge once" % heal_percent

func _on_option_pressed(_option: String) -> void:
    Game.finish_current_node()
