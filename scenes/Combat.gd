extends Control

@onready var info_label: Label = $VBox/InfoLabel
@onready var continue_button: Button = $VBox/CompleteButton

func _ready() -> void:
    info_label.text = _build_placeholder()
    continue_button.pressed.connect(_on_complete_pressed)

func _build_placeholder() -> String:
    var lines: Array[String] = []
    lines.append("Turn order prototype pending")
    lines.append("Party size: %d" % Game.get_party_overview().size())
    return "\n".join(lines)

func _on_complete_pressed() -> void:
    Game.open_rewards()
