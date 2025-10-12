extends Control

@onready var label: Label = $Label

func _ready() -> void:
    label.text = _build_placeholder()

func _build_placeholder() -> String:
    var lines: Array[String] = Array[String]()
    lines.append("Turn order prototype pending")
    lines.append("Party size: %d" % Game.get_party_overview().size())
    return "\n".join(lines)
