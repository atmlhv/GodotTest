extends Node

signal party_updated
signal ascension_updated(level: int)
signal gold_updated(amount: int)
signal inventory_updated(inventory: Array[Dictionary])

enum GameState {
    TITLE,
    MAP,
    COMBAT,
    REWARD,
    SHOP,
    REST,
}

const STATE_TO_SCENE: Dictionary = {
    GameState.TITLE: "res://scenes/Title.tscn",
    GameState.MAP: "res://scenes/Map.tscn",
    GameState.COMBAT: "res://scenes/Combat.tscn",
    GameState.REWARD: "res://scenes/Reward.tscn",
    GameState.SHOP: "res://scenes/Shop.tscn",
    GameState.REST: "res://scenes/Rest.tscn",
}

const MAP_COLUMNS: int = 10
const MAP_ROWS: int = 7
const MAP_NODE_WEIGHT_TABLE: Dictionary = {
    "battle": 5,
    "event": 2,
    "shop": 1,
    "rest": 1,
    "elite": 1,
}

const MAX_ITEM_SLOTS: int = 3
const GOLD_BASE_TABLE: Dictionary = {
    "battle": 26,
    "elite": 55,
    "boss": 120,
    "event": 12,
}
const GOLD_VARIANCE: int = 8

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
var _gold: int = 0
var _inventory_items: Array[Dictionary] = []
var _pending_reward: Dictionary = {}

func _ready() -> void:
    Data.data_loaded.connect(_on_data_loaded)
    Save.run_loaded.connect(_on_run_loaded)
    ascension_updated.emit(_ascension_level)
    gold_updated.emit(_gold)
    inventory_updated.emit(get_inventory())

func new_run(seed: int, ascension_level: int) -> void:
    _ascension_level = ascension_level
    ascension_updated.emit(_ascension_level)
    RNG.initialize_seeds(seed)
    _party_members = Data.create_default_party()
    party_updated.emit()
    _gold = 0
    _inventory_items = []
    _pending_reward = {}
    gold_updated.emit(_gold)
    inventory_updated.emit(get_inventory())
    _current_act = 1
    _generate_act_map(_current_act)
    _rng_seeds = RNG.get_seeds_snapshot()
    Save.autosave_async()
    set_state(GameState.MAP)

func set_state(value: GameState) -> void:
    if _current_state == value:
        return
    _current_state = value
    _transition_to_scene(_current_state)

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

func get_gold() -> int:
    return _gold

func add_gold(amount: int) -> void:
    if amount == 0:
        return
    _gold = max(0, _gold + amount)
    gold_updated.emit(_gold)
    Save.autosave_debounced()

func spend_gold(amount: int) -> bool:
    if amount <= 0:
        return true
    if amount > _gold:
        return false
    _gold -= amount
    gold_updated.emit(_gold)
    Save.autosave_debounced()
    return true

func get_max_item_slots() -> int:
    return MAX_ITEM_SLOTS

func get_inventory() -> Array[Dictionary]:
    var snapshot: Array[Dictionary] = []
    for entry in _inventory_items:
        snapshot.append(entry.duplicate(true))
    return snapshot

func add_item_to_inventory(item_id: String, quantity: int = 1) -> bool:
    if item_id == "":
        return true
    var index: int = _find_inventory_index(item_id)
    if index != -1:
        var entry: Dictionary = _inventory_items[index]
        entry["quantity"] = int(entry.get("quantity", 1)) + max(1, quantity)
        _inventory_items[index] = entry
        inventory_updated.emit(get_inventory())
        Save.autosave_debounced()
        return true
    if _inventory_items.size() >= MAX_ITEM_SLOTS:
        return false
    var new_entry: Dictionary = {
        "id": item_id,
        "quantity": max(1, quantity),
    }
    _inventory_items.append(new_entry)
    inventory_updated.emit(get_inventory())
    Save.autosave_debounced()
    return true

func replace_inventory_item(slot_index: int, item_id: String, quantity: int = 1) -> bool:
    if slot_index < 0 or slot_index >= _inventory_items.size():
        return false
    if item_id == "":
        return false
    var new_entry: Dictionary = {
        "id": item_id,
        "quantity": max(1, quantity),
    }
    _inventory_items[slot_index] = new_entry
    inventory_updated.emit(get_inventory())
    Save.autosave_debounced()
    return true

func remove_inventory_slot(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _inventory_items.size():
        return
    _inventory_items.remove_at(slot_index)
    inventory_updated.emit(get_inventory())
    Save.autosave_debounced()

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

func get_map_node(node_id: String) -> Dictionary:
    var node: Dictionary = _find_map_node(node_id)
    return node.duplicate(true)

func enter_map_node(node_id: String) -> void:
    if _map_state.is_empty():
        push_warning("Cannot enter map node without generated map")
        return
    var available: Array = _map_state.get("available", [])
    if not available.has(node_id):
        push_warning("Node %s is not currently selectable" % node_id)
        return
    var node: Dictionary = _find_map_node(node_id)
    if node.is_empty():
        push_warning("Unknown map node %s" % node_id)
        return
    _map_state["active"] = node_id
    if not _map_state.has("visited"):
        _map_state["visited"] = []
    var visited: Array = _map_state.get("visited", [])
    if not visited.has(node_id):
        visited.append(node_id)
        _map_state["visited"] = visited
    _map_state["available"] = []
    Save.autosave_async()
    set_state(_state_for_node_type(node.get("type", "battle")))

func open_rewards() -> void:
    ensure_reward_for_active_node()
    set_state(GameState.REWARD)

func ensure_reward_for_active_node() -> Dictionary:
    if not _pending_reward.is_empty():
        return _pending_reward.duplicate(true)
    var active_id: String = str(_map_state.get("active", ""))
    if active_id == "":
        _pending_reward = {}
        return Dictionary()
    var node: Dictionary = _find_map_node(active_id)
    if node.is_empty():
        _pending_reward = {}
        return Dictionary()
    _pending_reward = _generate_reward_for_node(node)
    return _pending_reward.duplicate(true)

func get_pending_reward() -> Dictionary:
    return _pending_reward.duplicate(true)

func claim_reward_gold() -> int:
    if _pending_reward.is_empty():
        return 0
    if _pending_reward.get("claimed_gold", false):
        return int(_pending_reward.get("gold", 0))
    var amount: int = int(_pending_reward.get("gold", 0))
    if amount > 0:
        add_gold(amount)
    _pending_reward["claimed_gold"] = true
    Save.autosave_debounced()
    return amount

func claim_reward_equipment(choice_index: int, member_index: int) -> bool:
    if _pending_reward.is_empty():
        return false
    if _pending_reward.get("claimed_equipment", false):
        return false
    var choices: Array = _pending_reward.get("equipment_choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return false
    if member_index < 0 or member_index >= _party_members.size():
        return false
    var choice_variant: Variant = choices[choice_index]
    if not (choice_variant is Dictionary):
        return false
    var equipment: Dictionary = choice_variant
    var slot: String = str(equipment.get("slot", ""))
    var equip_id: String = str(equipment.get("id", ""))
    if slot == "" or equip_id == "":
        return false
    var member: Dictionary = _party_members[member_index].duplicate(true)
    var loadout: Dictionary = member.get("equipment", {})
    loadout[slot] = equip_id
    member["equipment"] = loadout
    _party_members[member_index] = member
    _pending_reward["claimed_equipment"] = true
    _pending_reward["selected_equipment"] = choice_index
    _pending_reward["equipment_target"] = member_index
    party_updated.emit()
    Save.autosave_debounced()
    return true

func claim_reward_skill(choice_index: int, member_index: int) -> bool:
    if _pending_reward.is_empty():
        return false
    if _pending_reward.get("claimed_skill", false):
        return false
    var choices: Array = _pending_reward.get("skill_choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return false
    if member_index < 0 or member_index >= _party_members.size():
        return false
    var choice_variant: Variant = choices[choice_index]
    if not (choice_variant is Dictionary):
        return false
    var skill_id: String = str(choice_variant.get("id", ""))
    if skill_id == "":
        return false
    var member: Dictionary = _party_members[member_index].duplicate(true)
    var skills: Array = member.get("skills", [])
    if not skills.has(skill_id):
        skills.append(skill_id)
    member["skills"] = skills
    _party_members[member_index] = member
    _pending_reward["claimed_skill"] = true
    _pending_reward["selected_skill"] = choice_index
    _pending_reward["skill_target"] = member_index
    party_updated.emit()
    Save.autosave_debounced()
    return true

func try_claim_reward_item() -> bool:
    if _pending_reward.is_empty():
        return true
    if _pending_reward.get("claimed_item", false):
        return true
    var reward_item: Dictionary = _pending_reward.get("item_reward", Dictionary())
    if reward_item.is_empty():
        _pending_reward["claimed_item"] = true
        return true
    var item_id: String = str(reward_item.get("id", ""))
    if item_id == "":
        _pending_reward["claimed_item"] = true
        return true
    var quantity: int = int(reward_item.get("quantity", 1))
    if add_item_to_inventory(item_id, quantity):
        _pending_reward["claimed_item"] = true
        Save.autosave_debounced()
        return true
    return false

func replace_reward_item(slot_index: int) -> bool:
    if _pending_reward.is_empty():
        return false
    if _pending_reward.get("claimed_item", false):
        return false
    var reward_item: Dictionary = _pending_reward.get("item_reward", Dictionary())
    if reward_item.is_empty():
        _pending_reward["claimed_item"] = true
        return true
    var item_id: String = str(reward_item.get("id", ""))
    if item_id == "":
        return false
    var quantity: int = int(reward_item.get("quantity", 1))
    if replace_inventory_item(slot_index, item_id, quantity):
        _pending_reward["claimed_item"] = true
        Save.autosave_debounced()
        return true
    return false

func discard_reward_item() -> void:
    if _pending_reward.is_empty():
        return
    _pending_reward["claimed_item"] = true
    Save.autosave_debounced()

func finish_current_node() -> void:
    if _map_state.is_empty():
        set_state(GameState.MAP)
        return
    var active_id: String = str(_map_state.get("active", ""))
    if active_id == "":
        set_state(GameState.MAP)
        return
    var node: Dictionary = _find_map_node(active_id)
    var completed: Array = _map_state.get("completed", [])
    if not completed.has(active_id):
        completed.append(active_id)
        _map_state["completed"] = completed
    _map_state["active"] = ""
    var connections: Array = node.get("connections", [])
    if connections.is_empty():
        _handle_act_completion(node)
        return
    _map_state["available"] = connections.duplicate()
    _pending_reward = {}
    Save.autosave_async()
    set_state(GameState.MAP)

func snapshot_for_save() -> Dictionary:
    _rng_seeds = RNG.get_seeds_snapshot()
    var snapshot: Dictionary = Dictionary()
    snapshot["party"] = _party_members.duplicate(true)
    snapshot["ascension_level"] = _ascension_level
    snapshot["rng"] = _rng_seeds.duplicate(true)
    snapshot["state"] = int(_current_state)
    snapshot["act"] = _current_act
    snapshot["map_state"] = _map_state.duplicate(true)
    snapshot["gold"] = _gold
    snapshot["inventory"] = get_inventory()
    snapshot["pending_reward"] = _pending_reward.duplicate(true)
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
    _current_act = snapshot.get("act", 1)
    var saved_map: Variant = snapshot.get("map_state", Dictionary())
    if saved_map is Dictionary:
        _map_state = _sanitize_map_state(saved_map as Dictionary)
    else:
        _map_state = Dictionary()
    _gold = int(snapshot.get("gold", 0))
    var saved_inventory: Variant = snapshot.get("inventory", Array())
    _inventory_items = []
    if saved_inventory is Array:
        for entry in saved_inventory:
            if entry is Dictionary:
                _inventory_items.append((entry as Dictionary).duplicate(true))
    var saved_reward: Variant = snapshot.get("pending_reward", Dictionary())
    if saved_reward is Dictionary:
        _pending_reward = (saved_reward as Dictionary).duplicate(true)
    else:
        _pending_reward = {}
    party_updated.emit()
    ascension_updated.emit(_ascension_level)
    gold_updated.emit(_gold)
    inventory_updated.emit(get_inventory())
    set_state(_state_from_variant(state_value))

func _on_data_loaded() -> void:
    if _party_members.is_empty():
        _party_members = Data.create_default_party()
        party_updated.emit()

func _on_run_loaded(snapshot: Dictionary) -> void:
    restore_from_save(snapshot)

func _transition_to_scene(state: GameState) -> void:
    var path: String = _scene_path_for_state(state)
    if path == "":
        return
    call_deferred("_deferred_change_scene", path)

func _deferred_change_scene(path: String) -> void:
    var error: Error = get_tree().change_scene_to_file(path)
    if error != OK:
        push_error("Failed to change scene to %s: %s" % [path, error])

func _scene_path_for_state(state: GameState) -> String:
    if STATE_TO_SCENE.has(state):
        return STATE_TO_SCENE[state]
    return ""

func _generate_act_map(act: int) -> void:
    var columns: Array = []
    for column_index in range(MAP_COLUMNS):
        var node_count: int = 1 if column_index == MAP_COLUMNS - 1 else 3
        var column_nodes: Array = _create_nodes_for_column(act, column_index, node_count)
        columns.append(column_nodes)
    _assign_connections(columns)
    var available: Array = []
    if not columns.is_empty():
        for node_data in columns[0]:
            if node_data is Dictionary:
                available.append(node_data.get("id", ""))
    _map_state = Dictionary()
    _map_state["act"] = act
    _map_state["columns"] = columns
    _map_state["available"] = available
    _map_state["active"] = ""
    _map_state["completed"] = []
    _map_state["visited"] = []
    _map_state["columns_count"] = MAP_COLUMNS
    _map_state["rows_count"] = MAP_ROWS

func _create_nodes_for_column(act: int, column_index: int, node_count: int) -> Array:
    var column_nodes: Array = []
    var rows: Array = _select_rows(node_count)
    for entry_index in range(node_count):
        var node: Dictionary = {}
        node["id"] = "A%d-C%d-%d" % [act, column_index, entry_index]
        node["column"] = column_index
        node["row"] = rows[entry_index] if entry_index < rows.size() else 0
        node["type"] = "boss" if column_index == MAP_COLUMNS - 1 else _choose_node_type(column_index)
        node["connections"] = []
        column_nodes.append(node)
    return column_nodes

func _assign_connections(columns: Array) -> void:
    for column_index in range(columns.size() - 1):
        var current_column_variant: Variant = columns[column_index]
        var next_column_variant: Variant = columns[column_index + 1]
        if not (current_column_variant is Array and next_column_variant is Array):
            continue
        var current_column: Array = current_column_variant
        var next_column: Array = next_column_variant
        if next_column.is_empty():
            continue
        for next_node_variant in next_column:
            if next_node_variant is Dictionary:
                var prev_index: int = RNG.randi_range("map", 0, current_column.size() - 1)
                var prev_node: Dictionary = current_column[prev_index]
                var connections: Array = prev_node.get("connections", [])
                var next_id: String = next_node_variant.get("id", "")
                if next_id != "" and not connections.has(next_id):
                    connections.append(next_id)
                    prev_node["connections"] = connections
                    current_column[prev_index] = prev_node
        for node_index in range(current_column.size()):
            var node_variant: Variant = current_column[node_index]
            if not (node_variant is Dictionary):
                continue
            var node: Dictionary = node_variant
            var connections_list: Array = node.get("connections", [])
            if connections_list.is_empty():
                var target: Dictionary = next_column[RNG.randi_range("map", 0, next_column.size() - 1)]
                var target_id: String = target.get("id", "")
                if target_id != "":
                    connections_list.append(target_id)
            elif next_column.size() > 1 and RNG.randi_range("map", 0, 99) < 40:
                var extra_target: Dictionary = next_column[RNG.randi_range("map", 0, next_column.size() - 1)]
                var extra_id: String = extra_target.get("id", "")
                if extra_id != "" and not connections_list.has(extra_id):
                    connections_list.append(extra_id)
            node["connections"] = connections_list
            current_column[node_index] = node
        columns[column_index] = current_column

func _select_rows(node_count: int) -> Array:
    var rows: Array = []
    if node_count <= 1:
        rows.append(MAP_ROWS / 2)
        return rows
    for index in range(node_count):
        var value: int = int(round(float(index) * float(MAP_ROWS - 1) / float(node_count - 1)))
        rows.append(clampi(value, 0, MAP_ROWS - 1))
    return rows

func _choose_node_type(column_index: int) -> String:
    var pool: Array[String] = []
    for key in MAP_NODE_WEIGHT_TABLE.keys():
        var weight: int = int(MAP_NODE_WEIGHT_TABLE[key])
        if key == "elite" and column_index <= 1:
            weight = 0
        if weight <= 0:
            continue
        for _i in range(weight):
            pool.append(key)
    if pool.is_empty():
        return "battle"
    var choice_index: int = RNG.randi_range("map", 0, pool.size() - 1)
    return pool[choice_index]

func _state_for_node_type(node_type: String) -> GameState:
    match node_type:
        "battle", "elite", "boss":
            return GameState.COMBAT
        "shop":
            return GameState.SHOP
        "rest":
            return GameState.REST
        "event":
            return GameState.REWARD
        _:
            return GameState.MAP

func _generate_reward_for_node(node: Dictionary) -> Dictionary:
    var reward: Dictionary = {}
    var node_type: String = str(node.get("type", "battle"))
    reward["node_id"] = str(node.get("id", ""))
    reward["node_type"] = node_type
    var gold_amount: int = _compute_gold_reward(node_type)
    reward["gold"] = gold_amount
    reward["equipment_choices"] = _select_equipment_choices(3)
    var skill_choices: Array = _roll_skill_choices()
    reward["skill_choices"] = skill_choices
    var item_reward: Dictionary = _roll_item_reward()
    reward["item_reward"] = item_reward
    reward["claimed_gold"] = gold_amount <= 0
    reward["claimed_equipment"] = reward["equipment_choices"].is_empty()
    reward["claimed_skill"] = skill_choices.is_empty()
    reward["claimed_item"] = item_reward.is_empty()
    return reward

func _compute_gold_reward(node_type: String) -> int:
    var base: float = float(GOLD_BASE_TABLE.get(node_type, GOLD_BASE_TABLE.get("battle", 20)))
    var act_scale: float = 1.0 + 0.18 * float(max(0, _current_act - 1))
    base *= act_scale
    var modifiers: Dictionary = Data.get_ascension_level(_ascension_level)
    var reward_scale: float = float(modifiers.get("reward_gold_scale", 1.0))
    base *= reward_scale
    var variance: int = 0
    if GOLD_VARIANCE > 0:
        variance = RNG.randi_range("loot", -GOLD_VARIANCE, GOLD_VARIANCE)
    var total: int = int(round(base)) + variance
    return max(0, total)

func _select_equipment_choices(count: int) -> Array:
    var dataset: Variant = Data.get_dataset("equipment")
    var pool: Array = dataset if dataset is Array else []
    var selections: Array = []
    if pool.is_empty():
        return selections
    var taken: Array[int] = []
    var limit: int = min(count, pool.size())
    while selections.size() < limit and taken.size() < pool.size():
        var index: int = RNG.randi_range("loot", 0, pool.size() - 1)
        if taken.has(index):
            continue
        taken.append(index)
        var candidate: Variant = pool[index]
        if candidate is Dictionary:
            var entry: Dictionary = (candidate as Dictionary).duplicate(true)
            entry["display_name"] = _localize_name(entry)
            selections.append(entry)
    return selections

func _roll_skill_choices() -> Array:
    var results: Array = []
    var drop_chance: float = float(Balance.DEFAULTS.get("p_skill_drop", 0.35))
    if RNG.randf_range("loot", 0.0, 1.0) >= drop_chance:
        return results
    var dataset: Variant = Data.get_dataset("skills")
    var pool: Array = dataset if dataset is Array else []
    if pool.is_empty():
        return results
    var known_ids: Array[String] = _party_known_skill_ids()
    var available: Array = []
    for entry in pool:
        if entry is Dictionary:
            var skill_id: String = str(entry.get("id", ""))
            if skill_id == "":
                continue
            if not known_ids.has(skill_id):
                var copy: Dictionary = (entry as Dictionary).duplicate(true)
                copy["display_name"] = _localize_name(copy)
                available.append(copy)
    if available.is_empty():
        for entry in pool:
            if entry is Dictionary:
                var copy_all: Dictionary = (entry as Dictionary).duplicate(true)
                copy_all["display_name"] = _localize_name(copy_all)
                available.append(copy_all)
    if available.is_empty():
        return results
    var taken: Array[int] = []
    var limit: int = min(3, available.size())
    while results.size() < limit and taken.size() < available.size():
        var index: int = RNG.randi_range("loot", 0, available.size() - 1)
        if taken.has(index):
            continue
        taken.append(index)
        results.append((available[index] as Dictionary).duplicate(true))
    return results

func _roll_item_reward() -> Dictionary:
    var drop_chance: float = float(Balance.DEFAULTS.get("p_item_drop", 0.4))
    if RNG.randf_range("loot", 0.0, 1.0) >= drop_chance:
        return Dictionary()
    var dataset: Variant = Data.get_dataset("items")
    var pool: Array = dataset if dataset is Array else []
    if pool.is_empty():
        return Dictionary()
    var choice_variant: Variant = RNG.choice("loot", pool)
    if not (choice_variant is Dictionary):
        return Dictionary()
    var item: Dictionary = (choice_variant as Dictionary).duplicate(true)
    item["display_name"] = _localize_name(item)
    if not item.has("quantity"):
        item["quantity"] = 1
    return item

func _party_known_skill_ids() -> Array[String]:
    var result: Array[String] = []
    for member_variant in _party_members:
        if not (member_variant is Dictionary):
            continue
        var skills: Array = (member_variant as Dictionary).get("skills", [])
        for skill_variant in skills:
            var skill_id: String = str(skill_variant)
            if skill_id == "":
                continue
            if not result.has(skill_id):
                result.append(skill_id)
    return result

func _localize_name(entry: Dictionary) -> String:
    var raw_name: Variant = entry.get("name")
    if raw_name is Dictionary:
        var dict_name: Dictionary = raw_name
        if dict_name.has("ja"):
            return str(dict_name["ja"])
        if dict_name.has("en"):
            return str(dict_name["en"])
    elif raw_name is String:
        return raw_name
    return str(entry.get("id", "???"))

func _find_inventory_index(item_id: String) -> int:
    for index in range(_inventory_items.size()):
        var entry: Dictionary = _inventory_items[index]
        if str(entry.get("id", "")) == item_id:
            return index
    return -1

func _find_map_node(node_id: String) -> Dictionary:
    var columns: Array = _map_state.get("columns", [])
    for column_variant in columns:
        if column_variant is Array:
            for node_variant in column_variant:
                if node_variant is Dictionary and node_variant.get("id", "") == node_id:
                    return (node_variant as Dictionary).duplicate(true)
    return Dictionary()

func _handle_act_completion(node: Dictionary) -> void:
    var node_type: String = node.get("type", "")
    if node_type == "boss":
        if _current_act >= 3:
            _complete_run()
            return
        advance_act()
        _generate_act_map(_current_act)
        _pending_reward = {}
        Save.autosave_async()
        set_state(GameState.MAP)
        return
    _map_state["available"] = []
    _pending_reward = {}
    Save.autosave_async()
    set_state(GameState.MAP)

func _complete_run() -> void:
    _current_act = 1
    _map_state = Dictionary()
    _pending_reward = {}
    Save.autosave_async()
    set_state(GameState.TITLE)

func _sanitize_map_state(raw_state: Dictionary) -> Dictionary:
    var sanitized: Dictionary = {}
    sanitized["act"] = int(raw_state.get("act", _current_act))
    sanitized["columns_count"] = int(raw_state.get("columns_count", MAP_COLUMNS))
    sanitized["rows_count"] = int(raw_state.get("rows_count", MAP_ROWS))
    sanitized["active"] = str(raw_state.get("active", ""))
    sanitized["available"] = _string_array_from(raw_state.get("available", []))
    sanitized["completed"] = _string_array_from(raw_state.get("completed", []))
    sanitized["visited"] = _string_array_from(raw_state.get("visited", []))
    var columns_variant: Variant = raw_state.get("columns", [])
    var columns: Array = []
    if columns_variant is Array:
        for column_variant in columns_variant:
            if column_variant is Array:
                var column_array: Array = []
                for node_variant in column_variant:
                    if node_variant is Dictionary:
                        column_array.append((node_variant as Dictionary).duplicate(true))
                columns.append(column_array)
    sanitized["columns"] = columns
    return sanitized

func _string_array_from(value: Variant) -> Array:
    var result: Array = []
    if value is Array:
        for entry in value:
            result.append(str(entry))
    return result

func _state_from_variant(value: Variant) -> GameState:
    if value is int:
        for state_name in GameState.keys():
            if GameState[state_name] == value:
                return GameState[state_name]
        return GameState.TITLE
    elif value is String and GameState.has(value):
        return GameState[value]
    return GameState.TITLE
