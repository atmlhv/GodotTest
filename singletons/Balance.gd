extends Node

const DEFAULTS := {
    "p_skill_drop": 0.35,
    "p_item_drop": 0.40,
    "crit_rate": 0.05,
    "crit_mul": 1.5,
    "p_poison": 0.05,
    "sleep_turns": 2,
    "wake_chance": 0.5,
}

func physical_damage(attack: float, defense: float, element_multiplier: float, skill_power: float, variance: float, crit_multiplier: float, buff_multiplier: float, is_guarding: bool) -> int:
    var base := max(1.0, attack * 1.0 - defense * 0.6)
    var damage := base * element_multiplier * skill_power * variance * crit_multiplier * buff_multiplier
    if is_guarding:
        damage *= 0.5
    return max(1, floor(damage))

func magical_damage(matk: float, element_multiplier: float, skill_power: float, variance: float, crit_multiplier: float, buff_multiplier: float, is_guarding: bool) -> int:
    var base := matk * skill_power
    var damage := base * element_multiplier * variance * crit_multiplier * buff_multiplier
    if is_guarding:
        damage *= 0.5
    return max(1, floor(damage))

func crit_multiplier(has_crit: bool) -> float:
    return DEFAULTS["crit_mul"] if has_crit else 1.0

func status_turns(status: StringName) -> int:
    match status:
        "sleep":
            return DEFAULTS["sleep_turns"]
        _:
            return 0

func status_application_chance(status: StringName) -> float:
    match status:
        "poison":
            return DEFAULTS["p_poison"]
        _:
            return 0.0
