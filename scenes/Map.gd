extends Control

const TYPE_LABELS: Dictionary = {
	"battle": "Battle",
	"elite": "Elite",
	"event": "Event",
	"shop": "Shop",
	"rest": "Rest",
	"boss": "Boss",
}

@onready var act_label: Label = $MapContainer/VBox/ActLabel
@onready var instructions_label: Label = $MapContainer/VBox/InstructionsLabel
@onready var grid: GridContainer = $MapContainer/VBox/MapGrid
@onready var info_label: Label = $MapContainer/VBox/InfoLabel

var _grid_rows: int = 0
var _grid_columns: int = 0
var _cell_cache: Array[Control] = []

func _ready() -> void:
	_refresh_map()

func _refresh_map() -> void:
	var map_state: Dictionary = Game.get_map_state()
	if map_state.is_empty():
		_show_empty_state()
		return
	var act: int = map_state.get("act", Game.get_current_act())
	var ascension: int = Game.get_ascension_level()
	act_label.text = "Act %d (Ascension %d)" % [act, ascension]
	instructions_label.text = "Select a node to continue your run."
	var columns: Array = map_state.get("columns", [])
	var columns_count: int = map_state.get("columns_count", columns.size())
	var rows_count: int = map_state.get("rows_count", 0)
	_ensure_grid_cells(columns_count, rows_count)
	_clear_cells()
	var available: Array = map_state.get("available", [])
	var active_id: String = map_state.get("active", "")
	var completed: Array = map_state.get("completed", [])
	for column_index in range(columns.size()):
		var column_variant: Variant = columns[column_index]
		if not (column_variant is Array):
			continue
		var column_nodes: Array = column_variant
		for node_variant in column_nodes:
			if not (node_variant is Dictionary):
				continue
			var node: Dictionary = node_variant
			var row_index: int = int(node.get("row", 0))
			var cell: Control = _get_cell(column_index, row_index)
			if cell == null:
				continue
			var button := Button.new()
			button.text = _format_node_label(node)
			button.tooltip_text = _build_tooltip(node)
			button.disabled = not available.has(node.get("id", ""))
			button.custom_minimum_size = Vector2(120, 72)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			var node_id: String = node.get("id", "")
			if active_id == node_id:
				button.add_theme_color_override("font_color", Color.hex(0xffd166ff))
			elif completed.has(node_id):
				button.add_theme_color_override("font_color", Color.hex(0x8ec07cff))
			button.pressed.connect(Callable(self, "_on_node_pressed").bind(node_id))
			cell.add_child(button)
	info_label.text = _build_info_text(available)

func _show_empty_state() -> void:
	act_label.text = "No map available"
	instructions_label.text = "Return to the title screen and start a new run."
	info_label.text = ""
	grid.visible = false

func _ensure_grid_cells(columns: int, rows: int) -> void:
	grid.visible = columns > 0 and rows > 0
	if columns <= 0 or rows <= 0:
		return
	grid.columns = columns
	_grid_columns = columns
	var required: int = columns * rows
	while _cell_cache.size() < required:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(120, 90)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		_cell_cache.append(cell)
	while _cell_cache.size() > required:
		var removed: Control = _cell_cache.pop_back()
		removed.queue_free()
	_grid_rows = rows

func _clear_cells() -> void:
	for cell in _cell_cache:
		for child in cell.get_children():
			child.queue_free()

func _get_cell(column: int, row: int) -> Control:
	if _grid_rows <= 0 or _grid_columns <= 0:
		return null
	var clamped_row: int = clampi(row, 0, _grid_rows - 1)
	var clamped_column: int = clampi(column, 0, _grid_columns - 1)
	var index: int = clamped_row * _grid_columns + clamped_column
	if index < 0 or index >= _cell_cache.size():
		return null
	return _cell_cache[index]

func _format_node_label(node: Dictionary) -> String:
	var node_type: String = node.get("type", "battle")
	var label: String = TYPE_LABELS.get(node_type, node_type.capitalize())
	var column: int = int(node.get("column", 0)) + 1
	var row: int = int(node.get("row", 0)) + 1
	return "%s\nCol %d / Row %d" % [label, column, row]

func _build_tooltip(node: Dictionary) -> String:
	var node_type: String = node.get("type", "battle")
	var label: String = TYPE_LABELS.get(node_type, node_type.capitalize())
	var connections: Array = node.get("connections", [])
	if connections.is_empty():
		return "%s\nLeads to Act transition" % label
	var connection_labels: Array[String] = []
	for connection_id in connections:
		var target: Dictionary = Game.get_map_node(connection_id)
		if target.is_empty():
			continue
		var target_type: String = target.get("type", "battle")
		connection_labels.append(TYPE_LABELS.get(target_type, target_type.capitalize()))
	if connection_labels.is_empty():
		return "%s\nLeads to Act transition" % label
	return "%s\nNext: %s" % [label, ", ".join(connection_labels)]

func _build_info_text(available: Array) -> String:
	if available.is_empty():
		return "Complete the current encounter to unlock new paths."
	var labels: Array[String] = []
	for node_id in available:
		var data: Dictionary = Game.get_map_node(node_id)
		if data.is_empty():
			continue
		var node_type: String = data.get("type", "battle")
		labels.append(TYPE_LABELS.get(node_type, node_type.capitalize()))
	if labels.is_empty():
		return "Available nodes ready."
	labels.sort()
	return "Available nodes: %s" % ", ".join(labels)

func _on_node_pressed(node_id: String) -> void:
	Game.enter_map_node(node_id)
