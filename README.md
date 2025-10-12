# Command Rogue RPG (Prototype Skeleton)

This repository contains a Godot 4.5 project skeleton that follows the high-level specification for a command-based roguelike RPG. The initial commit focuses on establishing project structure, core singletons, deterministic RNG scaffolding, save system plumbing, and placeholder scenes with a shared party panel UI.

## Directory Layout
- `scenes/` – Playable scenes for Title, Map, Combat, Reward, Shop, and Rest.
- `singletons/` – Autoload scripts for game state, data loading, RNG, saving, audio, and balance calculations.
- `data/` – JSON datasets driving starter party members, skills, equipment, and ascension modifiers.
- `ui/` – Shared UI scenes and scripts, including the persistent party panel.
- `audio/` – Reserved for future audio assets.
- `tests/` – Placeholder for automated test scripts.

## Current Prototype Functionality
- **Title → Map flow**: Press **New Run** to seed deterministic RNG streams, generate an act map (10×7 DAG), and transition to the Map scene automatically.
- **Procedural map**: Each column of the act map contains selectable node buttons (Battle/Event/Shop/Rest/Elite) with deterministic connections leading to the Act boss.
- **Scene transitions**: Selecting a node routes to the appropriate placeholder scene (Combat/Reward/Shop/Rest) and returning completes the node, unlocking the next column. Boss clears advance to the next act until Act 3 victory returns to the Title screen.
- **Rewards preview**: The Reward scene pulls three equipment samples from `data/equipment.json` using the loot RNG stream and displays drop rate reminders from `Balance.gd` defaults.

## Getting Started
1. Open the project in Godot 4.5 or later.
2. Review `project.godot` autoload settings to ensure singletons load correctly.
3. Run the project and press **New Run** to see the generated map. Select nodes to move through the placeholder combat/reward/shop/rest loop and verify save/autosave hand-off.

## Next Steps
- Expand combat resolution, including turn order, skill targeting, and deterministic damage using `Balance.gd` helpers.
- Replace placeholder Reward/Shop/Rest logic with full inventory, equipment assignment, and resource updates.
- Add comprehensive tests under `tests/` to verify deterministic behavior and save/load integrity.

## Contribution Tips
- プルリクエスト作成前に `CONTRIBUTING.md` を参照し、`main` ブランチとのコンフリクトを解消してからプッシュしてください。

### 「自動マージできません」と表示された場合
GitHub の PR 画面で「This branch has conflicts that must be resolved」と表示された場合は、ローカルでブランチを最新化する必要があります。

1. まずローカル作業ツリーがクリーンであることを確認します。
   ```bash
   git status
   ```
2. 最新の `main` を取得します。
   ```bash
   git fetch origin main
   ```
3. 自分の作業ブランチに `main` を取り込みます。
   - マージする場合:
     ```bash
     git merge origin/main
     ```
   - リベースする場合:
     ```bash
     git rebase origin/main
     ```
4. コンフリクトが表示されたファイルを開き、どの変更を残すか決めて編集します。編集後は
   ```bash
   git add <file>
   ```
   でステージします。
5. マージの場合はマージコミットが作成されます。リベースの場合は
   ```bash
   git rebase --continue
   ```
   を実行して完了させます。
6. ローカルでビルドやテストを行い、問題が解決していることを確認します。
7. 最後に作業ブランチへプッシュします。リベースを行った場合は `--force-with-lease` が必要になる場合があります。
   ```bash
   git push origin <your-branch>
   # リベース後の強制プッシュ例
   git push --force-with-lease origin <your-branch>
   ```

これで PR のコンフリクト警告が解消され、自動マージが可能になります。
