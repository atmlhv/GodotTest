# Command Rogue RPG (Prototype Skeleton)

This repository contains a Godot 4.5 project skeleton that follows the high-level specification for a command-based roguelike RPG. The initial commit focuses on establishing project structure, core singletons, deterministic RNG scaffolding, save system plumbing, and placeholder scenes with a shared party panel UI.

## Directory Layout
- `scenes/` – Placeholder scenes for Title, Map, Combat, Reward, Shop, and Rest.
- `singletons/` – Autoload scripts for game state, data loading, RNG, saving, audio, and balance calculations.
- `data/` – JSON datasets driving starter party members, skills, equipment, and ascension modifiers.
- `ui/` – Shared UI scenes and scripts, including the persistent party panel.
- `audio/` – Reserved for future audio assets.
- `tests/` – Placeholder for automated test scripts.

## Getting Started
1. Open the project in Godot 4.5 or later.
2. Review `project.godot` autoload settings to ensure singletons load correctly.
3. Run the project to load the Title screen. Starting a new run seeds the RNG and populates placeholder UI elements.

## Next Steps
- Implement the procedural map generator and node interactions.
- Build out the combat system using the balance helpers and data-driven skills.
- Flesh out reward, shop, and rest logic using the JSON datasets.
- Add comprehensive tests under `tests/` to verify deterministic behavior and save/load integrity.
