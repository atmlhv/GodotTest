extends Control

@onready var start_button: Button = $VBox/StartButton
@onready var continue_button: Button = $VBox/ContinueButton
@onready var ascension_spin: SpinBox = $VBox/Ascension/AscensionSpin
@onready var seed_line: LineEdit = $VBox/Seed/SeedLine

func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)
    continue_button.pressed.connect(_on_continue_pressed)
    ascension_spin.value = Game.get_ascension_level()
    Save.run_loaded.connect(_on_run_loaded)
    _update_continue_button_state()

func _on_start_pressed() -> void:
    var ascension_level: int = int(ascension_spin.value)
    Game.set_ascension_level(ascension_level)
    var seed_text: String = seed_line.text.strip_edges()
    var seed: int = seed_text.hash() if seed_text != "" else int(Time.get_unix_time_from_system())
    Game.new_run(seed, ascension_level)
    Game.set_state(Game.GameState.MAP)
    _update_continue_button_state()
    _show_feedback("New run started with seed %d" % seed)

func _on_continue_pressed() -> void:
    Save.load_run()
    Game.set_state(Game.GameState.MAP)
    _show_feedback("Save loaded")

func _on_run_loaded(_snapshot: Dictionary) -> void:
    _update_continue_button_state()

func _update_continue_button_state() -> void:
    continue_button.disabled = not Save.has_saved_run()

func _show_feedback(text: String) -> void:
    OS.alert(text, "Info")
