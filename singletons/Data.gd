extends Node

signal data_loaded

var _cache: Dictionary = Dictionary()

func _ready() -> void:
	load_all()

func load_all() -> void:
	_cache.clear()
	_cache["party_templates"] = _load_json("res://data/party_templates.json")
	_cache["skills"] = _load_json("res://data/skills.json")
	_cache["equipment"] = _load_json("res://data/equipment.json")
	_cache["items"] = _load_json("res://data/items.json")
	_cache["ascension"] = _load_json("res://data/ascension.json")
	data_loaded.emit()

func get_dataset(name: String) -> Variant:
	return _cache.get(name)

func create_default_party() -> Array[Dictionary]:
	var party_templates: Array = _cache.get("party_templates", Array())
	var starters: Array[Dictionary] = []
	for template in party_templates:
		if template.get("starter", false):
			starters.append(template.duplicate(true))
	return starters

func get_skill_by_id(skill_id: String) -> Dictionary:
	for skill in _cache.get("skills", Array()):
		if skill.get("id") == skill_id:
			return skill
	return Dictionary()

func get_equipment_by_id(equip_id: String) -> Dictionary:
	for entry in _cache.get("equipment", Array()):
		if entry.get("id") == equip_id:
			return entry
	return Dictionary()

func get_item_by_id(item_id: String) -> Dictionary:
	for entry in _cache.get("items", Array()):
		if entry.get("id") == item_id:
			return entry
	return Dictionary()

func get_ascension_level(level: int) -> Dictionary:
	var table: Array = _cache.get("ascension", Array())
	for row in table:
		if row.get("level", -1) == level:
			return row
	return Dictionary()

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return Array()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open data file: %s" % path)
		return Array()
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var error := parser.parse(content)
	if error != OK:
		push_error("JSON parse error in %s at line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return Array()
	return parser.data
