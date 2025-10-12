extends Node

var _current_bgm: AudioStreamPlayer = null
var _bus_master: StringName = &"Master"

func play_bgm(stream: AudioStream, fade_time: float = 1.0) -> void:
    if stream == null:
        stop_bgm()
        return
    if _current_bgm == null:
        _current_bgm = AudioStreamPlayer.new()
        _current_bgm.bus = _bus_master
        add_child(_current_bgm)
    if _current_bgm.stream == stream and _current_bgm.playing:
        return
    _current_bgm.stream = stream
    _current_bgm.volume_db = -80.0
    _current_bgm.play()
    create_tween().tween_property(_current_bgm, "volume_db", 0.0, fade_time)

func stop_bgm(fade_time: float = 0.5) -> void:
    if _current_bgm == null or not _current_bgm.playing:
        return
    var tween := create_tween()
    tween.tween_property(_current_bgm, "volume_db", -80.0, fade_time)
    tween.tween_callback(Callable(_current_bgm, "stop"))

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
    if stream == null:
        return
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume_db
    player.bus = _bus_master
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
