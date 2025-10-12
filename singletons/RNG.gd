extends Node

const STREAM_KEYS := ["map", "ai", "action", "loot"]

var _streams: Dictionary = Dictionary()
var _master_seed: int = 0

func _ready() -> void:
    initialize_seeds(Time.get_ticks_msec())

func initialize_seeds(seed: int) -> void:
    _master_seed = seed
    _streams.clear()
    var seed_gen: RandomNumberGenerator = RandomNumberGenerator.new()
    seed_gen.seed = seed
    for key in STREAM_KEYS:
        var stream: RandomNumberGenerator = RandomNumberGenerator.new()
        stream.seed = seed_gen.randi()
        _streams[key] = stream

func randomize_stream(key: String) -> void:
    if not _streams.has(key):
        return
    _streams[key].randomize()

func randf_range(key: String, from: float, to: float) -> float:
    return _get_stream(key).randf_range(from, to)

func randi_range(key: String, from: int, to: int) -> int:
    return _get_stream(key).randi_range(from, to)

func choice(key: String, array: Array) -> Variant:
    if array.is_empty():
        return null
    var index: int = _get_stream(key).randi_range(0, array.size() - 1)
    return array[index]

func get_seeds_snapshot() -> Dictionary:
    var snapshot: Dictionary = {
        "master_seed": _master_seed,
        "streams": Dictionary(),
    }
    for key in STREAM_KEYS:
        var stream: RandomNumberGenerator = _streams.get(key)
        if stream:
            snapshot["streams"][key] = stream.state
    return snapshot

func restore_from_snapshot(snapshot: Dictionary) -> void:
    _master_seed = snapshot.get("master_seed", 0)
    initialize_seeds(_master_seed)
    var states: Dictionary = snapshot.get("streams", Dictionary())
    for key in STREAM_KEYS:
        if states.has(key) and _streams.has(key):
            _streams[key].state = states[key]

func _get_stream(key: String) -> RandomNumberGenerator:
    if not _streams.has(key):
        var stream: RandomNumberGenerator = RandomNumberGenerator.new()
        stream.seed = _master_seed + key.hash()
        _streams[key] = stream
    return _streams[key]
