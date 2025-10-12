extends Node

signal run_loaded(snapshot: Dictionary)

const SAVE_DIR := "user://saves"
const SAVE_PATH := SAVE_DIR + "/slot1.json"
const BACKUP_PATH := SAVE_PATH + ".bak"

var _pending_save: bool = false
var _last_snapshot: Dictionary = Dictionary()

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
    load_run()

func load_run() -> void:
    var snapshot: Dictionary = _read_snapshot()
    if snapshot.is_empty():
        return
    _last_snapshot = snapshot
    run_loaded.emit(snapshot)

func autosave_async() -> void:
    if not is_inside_tree():
        return
    call_deferred("_flush_save")

func autosave_debounced() -> void:
    if _pending_save:
        return
    _pending_save = true
    if not is_inside_tree():
        _pending_save = false
        return
    call_deferred("_flush_save")

func _flush_save() -> void:
    _pending_save = false
    var snapshot: Dictionary = Game.snapshot_for_save()
    _last_snapshot = snapshot
    _write_snapshot(snapshot)

func has_saved_run() -> bool:
    if not _last_snapshot.is_empty():
        return true
    _last_snapshot = _read_snapshot()
    return not _last_snapshot.is_empty()

func get_cached_snapshot() -> Dictionary:
    if _last_snapshot.is_empty():
        _last_snapshot = _read_snapshot()
    return _last_snapshot.duplicate(true)

func _read_snapshot() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return Dictionary()
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return Dictionary()
    var content := file.get_as_text()
    file.close()
    var parser := JSON.new()
    var result := parser.parse(content)
    if result != OK:
        push_error("Failed to parse save file: %s" % parser.get_error_message())
        return Dictionary()
    var data: Variant = parser.data
    if data is Dictionary:
        return data
    push_warning("Save data was not a dictionary; resetting state")
    return Dictionary()

func _write_snapshot(snapshot: Dictionary) -> void:
    var json := JSON.stringify(snapshot, "  ")
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Unable to open save file for writing: %s" % SAVE_PATH)
        return
    file.store_string(json)
    file.flush()
    file.close()
    _write_backup(json)

func _write_backup(content: String) -> void:
    var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Unable to create backup save at %s" % BACKUP_PATH)
        return
    file.store_string(content)
    file.close()
