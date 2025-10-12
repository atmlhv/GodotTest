extends Control

@onready var members_label: Label = $HBox/PartyInfo/Members
@onready var ascension_value_label: Label = $HBox/AscensionInfo/AscensionValue
@onready var gold_label: Label = $HBox/Resources/GoldLabel
@onready var items_label: Label = $HBox/Resources/ItemsLabel

func _ready() -> void:
    _refresh_panel()
    Game.party_updated.connect(_refresh_panel)
    Game.ascension_updated.connect(_on_ascension_updated)
    Game.gold_updated.connect(_on_gold_updated)
    Game.inventory_updated.connect(_on_inventory_updated)
    _on_gold_updated(Game.get_gold())
    _on_inventory_updated(Game.get_inventory())

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

func _on_gold_updated(amount: int) -> void:
    gold_label.text = "Gold: %d" % amount

func _on_inventory_updated(inventory: Array[Dictionary]) -> void:
    if inventory.is_empty():
        items_label.text = "Items: (empty)"
        return
    var parts: Array[String] = []
    for entry in inventory:
        var item_id: String = str(entry.get("id", ""))
        var quantity: int = int(entry.get("quantity", 1))
        var data: Dictionary = Data.get_item_by_id(item_id)
        var name: String = item_id
        if not data.is_empty():
            var raw_name: Variant = data.get("name")
            if raw_name is Dictionary and raw_name.has("ja"):
                name = str(raw_name["ja"])
            elif raw_name is Dictionary and raw_name.has("en"):
                name = str(raw_name["en"])
            elif raw_name is String:
                name = raw_name
        parts.append("%s x%d" % [name, quantity])
    items_label.text = "Items: " + ", ".join(parts)

func _format_member_line(member_data: Dictionary) -> String:
    var name: String = member_data.get("name", "???")
    var upgrades_variant: Variant = member_data.get("equipment_upgrades", {})
    if upgrades_variant is Dictionary:
        for value in (upgrades_variant as Dictionary).values():
            if int(value) > 0:
                name += "★"
                break
    var hp: int = member_data.get("hp", 0)
    var max_hp: int = member_data.get("max_hp", hp)
    var mp: int = member_data.get("mp", 0)
    var max_mp: int = member_data.get("max_mp", mp)
    var status: Array = member_data.get("status", Array())
    var status_text: String = "" if status.is_empty() else " [" + ", ".join(status) + "]"
    return "%s HP %d/%d MP %d/%d%s" % [name, hp, max_hp, mp, max_mp, status_text]
