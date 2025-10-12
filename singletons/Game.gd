extends Node

signal party_updated
signal ascension_updated(level: int)

enum GameState {
    TITLE,
    MAP,
    COMBAT,
    REWARD,
    SHOP,
    REST,
}

var _current_state: GameState = GameState.TITLE
var current_state: GameState:
    get:
        return _current_state
    set(value):
        set_state(value)
var _party_members: Array[Dictionary] = []
var _ascension_level: int = 0
var _rng_seeds: Dictionary = Dictionary()
var _current_act: int = 1
var _map_state: Dictionary = Dictionary()

func _ready() -> void:
    Data.data_loaded.connect(_on_data_loaded)
    Save.run_loaded.connect(_on_run_loaded)
    ascension_updated.emit(_ascension_level)

func new_run(seed: int, ascension_level: int) -> void:
    _ascension_level = ascension_level
    ascension_updated.emit(_ascension_level)
    RNG.initialize_seeds(seed)
    _party_members = Data.create_default_party()
    party_updated.emit()
    _map_state = Dictionary()
    _current_act = 1
    _rng_seeds = RNG.get_seeds_snapshot()
    Save.autosave_async()

func set_state(value: GameState) -> void:
    if _current_state == value:
        return
    _current_state = value
    # TODO: add transition handling

func get_party_overview() -> Array[Dictionary]:
    var clone: Array[Dictionary] = []
    for entry in _party_members:
        clone.append(entry.duplicate(true))
    return clone

func update_party_member(index: int, payload: Dictionary) -> void:
    if index < 0 or index >= _party_members.size():
        push_warning("Party index out of range: %d" % index)
        return
    _party_members[index] = _party_members[index].merged(payload)
    party_updated.emit()
    Save.autosave_debounced()

func get_ascension_level() -> int:
    return _ascension_level

func set_ascension_level(level: int) -> void:
    if level == _ascension_level:
        return
    _ascension_level = level
    ascension_updated.emit(level)
    Save.autosave_debounced()

func get_current_act() -> int:
    return _current_act

func advance_act() -> void:
    _current_act = clampi(_current_act + 1, 1, 3)
    Save.autosave_async()

func get_map_state() -> Dictionary:
    return _map_state.duplicate(true)

func set_map_state(new_state: Dictionary) -> void:
    _map_state = new_state.duplicate(true)
    Save.autosave_debounced()

func snapshot_for_save() -> Dictionary:
    _rng_seeds = RNG.get_seeds_snapshot()
    var snapshot: Dictionary = Dictionary()
    snapshot["party"] = _party_members.duplicate(true)
    snapshot["ascension_level"] = _ascension_level
    snapshot["rng"] = _rng_seeds.duplicate(true)
    snapshot["state"] = int(_current_state)
    snapshot["act"] = _current_act
    snapshot["map_state"] = _map_state.duplicate(true)
    return snapshot

func restore_from_save(snapshot: Dictionary) -> void:
    var saved_party: Variant = snapshot.get("party", Array())
    _party_members = []
    if saved_party is Array:
        for entry in saved_party:
            if entry is Dictionary:
                _party_members.append((entry as Dictionary).duplicate(true))
    _ascension_level = snapshot.get("ascension_level", 0)
    var saved_rng: Variant = snapshot.get("rng", Dictionary())
    if saved_rng is Dictionary:
        _rng_seeds = (saved_rng as Dictionary).duplicate(true)
    else:
        _rng_seeds = Dictionary()
    RNG.restore_from_snapshot(_rng_seeds)
    var state_value: Variant = snapshot.get("state", GameState.TITLE)
    if state_value is int:
        _current_state = state_value
    elif state_value is String:
        _current_state = GameState.get(state_value, GameState.TITLE)
    _current_act = snapshot.get("act", 1)
    var saved_map: Variant = snapshot.get("map_state", Dictionary())
    if saved_map is Dictionary:
        _map_state = (saved_map as Dictionary).duplicate(true)
    else:
        _map_state = Dictionary()
    party_updated.emit()
    ascension_updated.emit(_ascension_level)

func _on_data_loaded() -> void:
    if _party_members.is_empty():
        _party_members = Data.create_default_party()
        party_updated.emit()

func _on_run_loaded(snapshot: Dictionary) -> void:
    restore_from_save(snapshot)
