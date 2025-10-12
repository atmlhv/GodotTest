# Handoff Summary

This document captures the current state of the Godot 4.5 project and points out the most important follow-up tasks for the next contributor. It reflects the repository after the "Implement map-driven scene flow" milestone.

## Core Systems in Place

- **Singletons**
  - `Game.gd` drives high-level state: scene routing, deterministic act map generation, autosave hooks, and party/ascension bookkeeping. Encounters remain placeholders, but scene transitions and map traversal rules function end-to-end.
  - `Data.gd`, `RNG.gd`, `Balance.gd`, and `Save.gd` are autoloads that respectively load JSON datasets, provide multi-stream deterministic RNG, expose baseline combat formulas, and manage the single-slot autosave/backup files.

- **Scenes & UI**
  - Title, Map, Combat, Reward, Shop, Rest, and a shared `PartyPanel` scene exist with typed scripts and placeholder flows. The title screen supports seeded new runs, ascension selection, and resume-from-save.
  - The map scene renders a 10×7 DAG, highlights available/active/completed nodes, and populates tooltips using generated node metadata.

- **Data**
  - Starter party templates, sample skills/equipment, and ascension modifier scaffolding live in `res://data/*.json` for future expansion.

## Outstanding Work vs. Spec

The project currently implements structural scaffolding but lacks most gameplay depth promised in the original spec. Key gaps include:

- **Combat System** — No initiative queue, command input, damage resolution, enemy AI, status handling, or wagon formation logic yet; the combat scene is only a placeholder. Implement the full turn-based loop, RNG variance streams, buffs/debuffs, guard mechanics, KO handling, and victory/defeat transitions.
- **Rewards & Economy** — Reward, shop, and rest scenes display static text and immediately finish nodes without granting loot, skills, gold, upgrades, or enforcing item capacity. Implement reward distribution rules, shop inventory/transactions, rest effects, and smith upgrades per spec.
- **Data-driven Entities** — Party members and enemies lack runtime stats, skill lists, equipment, XP/leveling, and status tracking beyond simple strings. Expand JSON schemas and the `Game`/`Data` layers to support these systems.
- **Events & Map Variety** — Map nodes branch procedurally, but event content itself is missing. Add event scenes/data (e.g., joiners, narrative choices) and ensure node types influence future map generation where required.
- **Save/Load Completeness** — Autosaves capture the basics (party, RNG seeds, map), but combat, inventory, and shop data will need to be serialized once implemented. Plan serialization formats early to avoid breaking compatibility.
- **Testing & Tooling** — No automated tests or headless CI checks run. Godot CLI is unavailable in this container; establish reproducible testing steps once tooling access is arranged (e.g., GUT tests, `--headless --check-only`, or editor-based smoke tests).

## Technical Notes & Recommendations

- The project enforces explicit typing to avoid Variant inference errors; prefer typed arrays/dictionaries and `.duplicate(true)` when cloning runtime data.
- RNG streams are separated by purpose (`map`, `ai`, `action`, `loot`). Use the appropriate stream to keep runs deterministic.
- The `PartyPanel` should stay visible across scenes. Keep it in sync with `Game.party_updated` and extend it with HP/MP bars, status icons, and forge marks as combat systems arrive.
- Review the original specification (`siyou.txt`) before expanding systems to stay aligned with requirements (ascension scaling, item cap, statuses, etc.).

## Suggested Next Steps

1. Flesh out the combat loop (formation, turn order, command selection, execution) with data-driven skills and deterministic RNG.
2. Implement reward distribution and inventory management, including equipment selection UI and the 3-item inventory cap.
3. Build shop, rest, and event scenes that consume/modify persistent state, integrating tightly with `Save` snapshots.
4. Add minimal automated validation (GDScript unit tests or headless smoke checks) once the Godot CLI is available or by leveraging in-editor test frameworks.

This handoff should give the next contributor enough context to continue aligning the project with the full spec.
