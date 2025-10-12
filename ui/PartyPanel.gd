extends Control

@onready var members_label: Label = $HBox/PartyInfo/Members
@onready var ascension_value_label: Label = $HBox/AscensionInfo/AscensionValue

func _ready() -> void:
    _refresh_panel()
    Game.party_updated.connect(_refresh_panel)
    Game.ascension_updated.connect(_on_ascension_updated)

func _refresh_panel() -> void:
    var lines: Array[String] = []
    for member_data in Game.get_party_overview():
        lines.append(_format_member_line(member_data))
    if lines.is_empty():
        members_label.text = "No party members loaded"
    else:
        members_label.text = "\n".join(lines)

func _on_ascension_updated(level: int) -> void:
    ascension_value_label.text = str(level)

func _format_member_line(member_data: Dictionary) -> String:
    var name: String = member_data.get("name", "???")
    var hp: int = member_data.get("hp", 0)
    var max_hp: int = member_data.get("max_hp", hp)
    var mp: int = member_data.get("mp", 0)
    var max_mp: int = member_data.get("max_mp", mp)
    var status: Array = member_data.get("status", [])
    var status_text := "" if status.is_empty() else " [" + ", ".join(status) + "]"
    return "%s HP %d/%d MP %d/%d%s" % [name, hp, max_hp, mp, max_mp, status_text]
