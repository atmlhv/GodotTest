extends Control

const MAX_FRONTLINE_SIZE: int = 4
const MAX_TURNS: int = 12
const RNG_STREAM_ACTION := "action"
const RNG_STREAM_AI := "ai"
const VARIANCE_MIN: float = 0.9
const VARIANCE_MAX: float = 1.1

@onready var info_label: Label = $VBox/InfoLabel
@onready var continue_button: Button = $VBox/CompleteButton

var _battle_log: Array[String] = []
var _simulation: BattleSimulation
var _battle_result: Dictionary = {}

func _ready() -> void:
    continue_button.disabled = true
    continue_button.pressed.connect(_on_complete_pressed)
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _start_simulation()

func _start_simulation() -> void:
    var party_overview: Array[Dictionary] = Game.get_party_overview()
    var enemy_wave: Array[Dictionary] = _select_enemy_wave(Game.get_current_act())
    _simulation = BattleSimulation.new(party_overview, enemy_wave, MAX_TURNS)
    _simulation.run()
    _battle_log = _simulation.get_log()
    _battle_result = _simulation.get_result()
    info_label.text = "\n".join(_battle_log)
    _apply_party_results(_simulation.get_party_snapshot())
    continue_button.disabled = false
    continue_button.text = tr("Collect Rewards") if _battle_result.get("victory", false) else tr("Continue")

func _apply_party_results(snapshot: Array[Dictionary]) -> void:
    for entry in snapshot:
        var index: int = int(entry.get("index", -1))
        if index < 0:
            continue
        var payload: Dictionary = {}
        if entry.has("hp"):
            payload["hp"] = entry["hp"]
        if entry.has("mp"):
            payload["mp"] = entry["mp"]
        if not payload.is_empty():
            Game.update_party_member(index, payload)

func _select_enemy_wave(act: int) -> Array[Dictionary]:
    var dataset: Array = Data.get_dataset("enemies")
    if dataset.is_empty():
        return [_build_default_enemy("Training Dummy", 40, 0, 8, 4, 6, 4, ["attack_basic"])]
    var wave: Array[Dictionary] = []
    var count: int = clampi(2 + act, 1, 4)
    for i in range(count):
        var definition: Dictionary = RNG.choice(RNG_STREAM_AI, dataset)
        if definition == null:
            definition = dataset[0]
        wave.append(definition.duplicate(true))
    return wave

func _build_default_enemy(name: String, hp: int, mp: int, atk: int, def: int, agi: int, matk: int, skills: Array[String]) -> Dictionary:
    return {
        "id": "training_dummy",
        "name": name,
        "hp": hp,
        "mp": mp,
        "atk": atk,
        "def": def,
        "agi": agi,
        "matk": matk,
        "skills": skills,
    }

func _on_complete_pressed() -> void:
    if _battle_result.get("victory", false):
        Game.open_rewards()
    else:
        Game.set_state(Game.GameState.MAP)

class BattleSimulation:
    var _allies: Array[BattleEntity] = []
    var _enemies: Array[BattleEntity] = []
    var _log: Array[String] = []
    var _turns_elapsed: int = 0
    var _max_turns: int

    func _init(party_payload: Array[Dictionary], enemy_payload: Array[Dictionary], max_turns: int) -> void:
        _max_turns = max_turns
        _build_allies(party_payload)
        _build_enemies(enemy_payload)

    func run() -> void:
        if _allies.is_empty() or _enemies.is_empty():
            _log.append("Battle could not be initialized.")
            return
        while not _battle_finished() and _turns_elapsed < _max_turns:
            _turns_elapsed += 1
            _log.append("=== Turn %d ===" % _turns_elapsed)
            _refresh_frontline()
            var order: Array[BattleEntity] = _build_turn_order()
            for actor in order:
                if _battle_finished():
                    break
                if not actor.is_alive():
                    continue
                _process_action(actor)
            _end_of_turn()
        if _all_enemies_down():
            _log.append("Victory! All enemies defeated.")
        elif _all_allies_down():
            _log.append("Defeat... the party has fallen.")
        else:
            _log.append("The battle ends in a stalemate after %d turns." % _max_turns)

    func get_log() -> Array[String]:
        return _log.duplicate()

    func get_result() -> Dictionary:
        return {
            "victory": _all_enemies_down(),
            "party_defeated": _all_allies_down(),
            "turns": _turns_elapsed,
        }

    func get_party_snapshot() -> Array[Dictionary]:
        var snapshot: Array[Dictionary] = []
        for entity in _allies:
            snapshot.append({
                "index": entity.index,
                "hp": entity.hp,
                "mp": entity.mp,
            })
        return snapshot

    func _build_allies(party_payload: Array[Dictionary]) -> void:
        for i in range(party_payload.size()):
            var member: Dictionary = party_payload[i]
            var frontline: bool = i < MAX_FRONTLINE_SIZE
            var entity := BattleEntity.new(member, false, i, frontline)
            _allies.append(entity)

    func _build_enemies(enemy_payload: Array[Dictionary]) -> void:
        var capped_payload: Array[Dictionary] = []
        for i in range(enemy_payload.size()):
            if i >= 8:
                break
            capped_payload.append(enemy_payload[i].duplicate(true))
        if capped_payload.is_empty():
            capped_payload.append(_default_enemy())
        for definition in capped_payload:
            var entity := BattleEntity.new(definition, true, -1, true)
            _enemies.append(entity)

    func _default_enemy() -> Dictionary:
        return {
            "id": "fallback_enemy",
            "name": "Training Dummy",
            "hp": 40,
            "mp": 0,
            "atk": 8,
            "def": 4,
            "agi": 6,
            "matk": 4,
            "skills": ["attack_basic"],
        }

    func _battle_finished() -> bool:
        return _all_allies_down() or _all_enemies_down()

    func _all_allies_down() -> bool:
        for entity in _allies:
            if entity.is_alive():
                return false
        return true

    func _all_enemies_down() -> bool:
        for entity in _enemies:
            if entity.is_alive():
                return false
        return true

    func _refresh_frontline() -> void:
        var current_front: Array[BattleEntity] = []
        for ally in _allies:
            if ally.frontline and not ally.is_alive():
                ally.frontline = false
            if ally.frontline and ally.is_alive():
                current_front.append(ally)
        if current_front.size() >= MAX_FRONTLINE_SIZE:
            return
        for ally in _allies:
            if current_front.size() >= MAX_FRONTLINE_SIZE:
                break
            if not ally.frontline and ally.is_alive():
                ally.frontline = true
                current_front.append(ally)
                _log.append("%s moves into the frontline." % ally.name)

    func _build_turn_order() -> Array[BattleEntity]:
        var participants: Array[BattleEntity] = []
        for ally in _allies:
            if ally.frontline and ally.is_alive():
                ally.roll_initiative()
                participants.append(ally)
        for enemy in _enemies:
            if enemy.is_alive():
                enemy.roll_initiative()
                participants.append(enemy)
        participants.sort_custom(self, "_sort_by_initiative")
        return participants

    func _sort_by_initiative(a: BattleEntity, b: BattleEntity) -> bool:
        if a.initiative == b.initiative:
            return a.get_stat("agi") > b.get_stat("agi")
        return a.initiative > b.initiative

    func _process_action(entity: BattleEntity) -> void:
        if entity.guard_active:
            entity.guard_active = false
        if entity.has_status("sleep"):
            _log.append("%s is fast asleep." % entity.name)
            entity.tick_status("sleep")
            return
        if entity.is_enemy:
            _enemy_action(entity)
        else:
            _ally_action(entity)

    func _enemy_action(entity: BattleEntity) -> void:
        var targets: Array[BattleEntity] = _live_frontline_allies()
        if targets.is_empty():
            targets = _live_allies()
        if targets.is_empty():
            return
        var skill := _choose_skill(entity)
        if skill.is_empty():
            _guard(entity)
            return
        var target: BattleEntity = RNG.choice(RNG_STREAM_AI, targets)
        if target == null:
            target = targets[0]
        _execute_skill(entity, skill, target)

    func _ally_action(entity: BattleEntity) -> void:
        var enemies := _live_enemies()
        if enemies.is_empty():
            return
        var skill := _choose_skill(entity)
        if skill.is_empty():
            _guard(entity)
            return
        var target: BattleEntity = _select_target_for_skill(entity, skill)
        if target == null:
            _guard(entity)
            return
        _execute_skill(entity, skill, target)

    func _choose_skill(entity: BattleEntity) -> Dictionary:
        for skill_id in entity.skills:
            var skill: Dictionary = Data.get_skill_by_id(skill_id)
            if skill.is_empty():
                continue
            var skill_type: String = str(skill.get("type", "skill"))
            var cost: int = int(skill.get("cost_mp", 0))
            if skill_type == "spell" and entity.has_status("silence"):
                continue
            if cost > entity.mp:
                continue
            return skill
        return Dictionary()

    func _select_target_for_skill(entity: BattleEntity, skill: Dictionary) -> BattleEntity:
        var target_mode: String = str(skill.get("target", "enemy_single"))
        match target_mode:
            "ally_single":
                var pool: Array[BattleEntity] = _live_enemies() if entity.is_enemy else _live_allies()
                if pool.is_empty():
                    return null
                return pool[0]
            _:
                var opponents: Array[BattleEntity] = _live_allies() if entity.is_enemy else _live_enemies()
                if opponents.is_empty():
                    return null
                var frontline := _live_frontline_allies() if entity.is_enemy else _live_enemies()
                if entity.is_enemy and not frontline.is_empty():
                    opponents = frontline
                var choice: BattleEntity = RNG.choice(RNG_STREAM_AI, opponents)
                return choice if choice != null else opponents[0]

    func _execute_skill(attacker: BattleEntity, skill: Dictionary, target: BattleEntity) -> void:
        var name_en: Dictionary = skill.get("name", {})
        var localized_name: String = str(name_en.get("en", skill.get("id", "Skill")))
        var cost: int = int(skill.get("cost_mp", 0))
        if cost > 0:
            attacker.mp = max(0, attacker.mp - cost)
        var skill_type: String = str(skill.get("type", "skill"))
        var element_multiplier: float = 1.0
        var variance: float = RNG.randf_range(RNG_STREAM_ACTION, VARIANCE_MIN, VARIANCE_MAX)
        var has_crit: bool = _roll_crit(attacker)
        var crit_multiplier: float = max(1.0, attacker.get_stat("critx")) if has_crit else 1.0
        var power: float = float(skill.get("power", 1.0))
        var buff_multiplier: float = 1.0
        var damage: int = 0
        if skill_type == "spell":
            damage = Balance.magical_damage(attacker.get_stat("matk"), element_multiplier, power, variance, crit_multiplier, buff_multiplier, target.guard_active)
        else:
            damage = Balance.physical_damage(attacker.get_stat("atk"), target.get_stat("def"), element_multiplier, power, variance, crit_multiplier, buff_multiplier, target.guard_active)
        var prefix: String = "%s uses %s" % [attacker.name, localized_name]
        if has_crit:
            prefix += " (CRIT!)"
        _log.append("%s for %d damage on %s." % [prefix, damage, target.name])
        _apply_damage(target, damage)

    func _apply_damage(target: BattleEntity, damage: int) -> void:
        damage = max(0, damage)
        if damage <= 0:
            _log.append("No damage was dealt to %s." % target.name)
            return
        target.hp = max(0, target.hp - damage)
        if target.has_status("sleep") and target.is_alive():
            var wake_roll: float = RNG.randf_range(RNG_STREAM_ACTION, 0.0, 1.0)
            if wake_roll <= Balance.DEFAULTS.get("wake_chance", 0.5):
                target.clear_status("sleep")
                _log.append("%s wakes up!" % target.name)
        if target.hp <= 0:
            _log.append("%s is defeated." % target.name)

    func _guard(entity: BattleEntity) -> void:
        entity.guard_active = true
        _log.append("%s takes a defensive stance." % entity.name)

    func _roll_crit(entity: BattleEntity) -> bool:
        var chance: float = entity.get_stat("crit")
        if chance <= 0.0:
            chance = Balance.DEFAULTS.get("crit_rate", 0.05)
        return RNG.randf_range(RNG_STREAM_ACTION, 0.0, 1.0) <= chance

    func _end_of_turn() -> void:
        for entity in _combined_entities():
            if not entity.is_alive():
                continue
            if entity.has_status("poison"):
                var poison_damage: int = max(1, int(floor(entity.max_hp * 0.05)))
                _log.append("Poison deals %d damage to %s." % [poison_damage, entity.name])
                entity.hp = max(0, entity.hp - poison_damage)
                entity.tick_status("poison")
                if entity.hp <= 0:
                    _log.append("%s succumbs to poison." % entity.name)
                    continue
            if entity.has_status("silence"):
                entity.tick_status("silence")

    func _combined_entities() -> Array[BattleEntity]:
        var combined: Array[BattleEntity] = []
        combined.append_array(_allies)
        combined.append_array(_enemies)
        return combined

    func _live_enemies() -> Array[BattleEntity]:
        var result: Array[BattleEntity] = []
        for entity in _enemies:
            if entity.is_alive():
                result.append(entity)
        return result

    func _live_allies() -> Array[BattleEntity]:
        var result: Array[BattleEntity] = []
        for entity in _allies:
            if entity.is_alive():
                result.append(entity)
        return result

    func _live_frontline_allies() -> Array[BattleEntity]:
        var result: Array[BattleEntity] = []
        for entity in _allies:
            if entity.is_alive() and entity.frontline:
                result.append(entity)
        return result

class BattleEntity:
    var index: int
    var name: String
    var is_enemy: bool
    var frontline: bool
    var hp: int
    var max_hp: int
    var mp: int
    var max_mp: int
    var stats: Dictionary
    var skills: Array[String] = []
    var statuses: Dictionary = {}
    var guard_active: bool = false
    var initiative: int = 0

    func _init(payload: Dictionary, enemy: bool, party_index: int, frontline_member: bool) -> void:
        index = party_index
        is_enemy = enemy
        frontline = frontline_member
        name = str(payload.get("name", payload.get("id", "Unknown")))
        max_hp = int(payload.get("max_hp", payload.get("hp", 1)))
        hp = clampi(int(payload.get("hp", max_hp)), 0, max_hp)
        max_mp = int(payload.get("max_mp", payload.get("mp", 0)))
        mp = clampi(int(payload.get("mp", max_mp)), 0, max_mp)
        stats = {
            "atk": float(payload.get("atk", 0)),
            "def": float(payload.get("def", 0)),
            "agi": float(payload.get("agi", 0)),
            "matk": float(payload.get("matk", 0)),
            "rec": float(payload.get("rec", 0)),
            "crit": float(payload.get("crit", Balance.DEFAULTS.get("crit_rate", 0.05))),
            "critx": float(payload.get("critx", Balance.DEFAULTS.get("crit_mul", 1.5))),
        }
        skills = []
        for entry in payload.get("skills", []):
            skills.append(str(entry))
        if skills.is_empty():
            skills.append("attack_basic")
        statuses = {}
        guard_active = false

    func is_alive() -> bool:
        return hp > 0

    func get_stat(stat: StringName) -> float:
        return float(stats.get(stat, 0.0))

    func has_status(status: StringName) -> bool:
        return statuses.has(status)

    func clear_status(status: StringName) -> void:
        statuses.erase(status)

    func add_status(status: StringName, duration: int) -> void:
        statuses[status] = {
            "remaining": duration,
        }

    func tick_status(status: StringName) -> void:
        if not statuses.has(status):
            return
        var entry: Dictionary = statuses[status]
        entry["remaining"] = int(entry.get("remaining", 1)) - 1
        if entry["remaining"] <= 0:
            statuses.erase(status)
        else:
            statuses[status] = entry

    func roll_initiative() -> void:
        initiative = int(get_stat("agi")) + RNG.randi_range(RNG_STREAM_ACTION, 0, 10)
*** End Patch
