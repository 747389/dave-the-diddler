# Man Versus Machine — Game Details

This project targets Godot 4.7.2.

## Game concept

A human fights the strongest machine and its rebuilt units. The campaign has five boss encounters. When one human dies, the strongest robot restores every defeated boss and the next human must begin again with Bolt. Gears, upgrades, and unlocked technology carry forward to the next human. The reinforced frame and other machine-like upgrades are intentional parts of the human-versus-machine theme. The original project folder name is unrelated to the game concept.

## Campaign flow

1. Start a campaign from the title screen and enter the current boss arena.
2. Defeat the boss to collect its gear bounty and preserve the surviving frame's health.
3. Choose one of two post-boss platforms: the Repair / Refit Shop, or the next boss. On the final stage, the second choice ends the campaign.
4. The Repair / Refit Shop allows upgrades and ability unlocks. During a cleared-stage intermission, a full frame repair costs 20 gears.
5. On death, the next human returns to Bolt with full health. Gears, upgrades, and unlocks remain; stage progress resets to the first boss.
6. Defeat Regent, the fifth boss, to finish the campaign.

## Bosses

| Stage | Boss | Health | Attack pattern |
|---|---|---:|---|
| 1 | Bolt, the Scrapper | 600 | Telegraphs a cross-arena charge. Jump over it. |
| 2 | Hopper, the Piston | 950 | Sends three-height ripple waves across the arena. The boss's head is the safe pocket. |
| 3 | Ripsaw, the Cutter | 1,425 | Fires two timed volleys of bolts in every direction. |
| 4 | Bulwark, the Warden | 2,025 | Sends full-height shield walls through the arena. Dash through them during invulnerability frames. |
| 5 | Regent, the Machine Heart | 2,800 | Jumps and flash-steps between fast radial volleys and crossing walls. |

Boss health is five times the former stage value. Every major attack has a light red polygon warning around the boss. The default warning is 0.35 seconds and each stage resource can adjust it. Each boss has its own attack script; the shared `BossRobot` class handles health, movement, gravity, contact, optional jumping and flash-stepping, and attack timing.

## Controls

- Move: A/D or Left/Right arrow keys
- Jump: Space, W, or Up arrow
- Light attack: M1 (left mouse button)
- Heavy attack: M2 (right mouse button); after three light attacks, the next heavy attack deals bonus damage
- Dash: Q
- Special ability 1: Z (EMP Burst, unlock required)
- Special ability 2: X (Emergency Repair, unlock required)
- Special ability 3: C (Overdrive, unlock required)
- Interact with post-boss choices: E
- Pause/resume: Escape
- Restart from Bolt: Ctrl+R

## Combat and collision

- M1 performs a light attack. M2 deals twice the base light-attack damage. Three landed M1 attacks empower the next M2.
- The base jump is lower than before to keep arena movement focused on the boss attacks.
- Dashing grants invulnerability for the dash plus a short recovery window. Overdrive grants a shorter invulnerability window on activation.
- During invulnerability, the player's collision layer is disabled so projectile and attack areas do not register a hit. The normal player layer is restored when invulnerability ends.
- Collision layer names are set in the project: Map is layer 1, Player is layer 2, Bosses is layer 3, and Attacks is layer 4. In Godot masks these correspond to bit values 1, 2, 4, and 8.
- Arena and test-map side walls use infinite `WorldBoundaryShape2D` planes, so the player cannot jump over a finite wall collider. Boss arenas and the movement test room have no traversal platforms. The tutorial retains its jump objective platform.
- The arena HUD lists only special-ability inputs that are currently unlocked. The player emits small gray square particles while running and jumping.

## Upgrades and shop

Stat upgrades include damage, movement speed, jump power, dash power, dash length, maximum health, attack speed, armor, and Salvage Kit gear bonus. Prices grow by level and upgrades have level caps.

Ability unlocks include Double Jump, EMP Burst, Emergency Repair, and Overdrive (internal resource key: `overclock`). Upgrades and unlocks persist between human lives for the current game session; they are not saved after closing the game.

## Project structure

Scenes and scripts use matching gameplay categories:

- `scenes/player/` and `scripts/player/` — player scene, movement, combat, and abilities.
- `scenes/bosses/` and `scripts/bosses/` — boss scenes and one attack script per boss; `attacks/` contains reusable collision-shape attack construction; `minions/` is reserved for summons.
- `scenes/arenas/` and `scripts/world/` — arena scenes and world orchestration.
- `scenes/tutorial/` and `scripts/tutorial/` — guided movement and combat practice.
- `scenes/ui/` and `scripts/ui/` — title screen, pause menu, shop, and victory screen.
- `scripts/autoload/` — `Global` run state and `DataRegistry` resource loading.
- `scripts/helpers/` — shared helper functions.
- `sounds/` and `shaders/` — project-root folders for audio and shader resources.
- `data/resource_scripts/` — custom resource types; `data/stages/`, `data/upgrades/`, and `data/unlocks/` — editable `.tres` definitions.

Each stage resource selects a boss scene and configures health, damage, attack interval, warning time, and optional jump or flash-step behavior. Keep boss-specific attack behavior in that boss's script. Prefer small reusable helpers and custom resources over large hard-coded dictionaries.

## Current implementation notes

- `project.godot` starts at the title screen and names the project Man Versus Machine.
- `scenes/arenas/arena.tscn` contains the clear boss arena; it has a floor and world-boundary side walls, with no traversal platforms.
- `scenes/arenas/test_map.tscn` is a flat movement room with world-boundary side walls.
- `scenes/tutorial/tutorial.tscn` has move, jump, and training-dummy objectives.
- `scenes/bosses/robot.tscn` is the shared boss body scene. Bolt, Hopper, Ripsaw, Bulwark, and Regent each have their own scene and script extending `BossRobot`.
- `scripts/bosses/attacks/boss_attack.gd` builds visible circular projectiles, ripple bars, and shield walls with matching collision shapes.
- Boss damage awards gears per applied hit, and each boss grants its clear bounty once.
- The post-boss arena offers only Repair / Refit Shop and next-stage choices. The repair button restores the carried frame for 20 gears.
- On death, stage progress resets to Bolt while gears and purchased technology persist for the next human.

## Project maintenance instruction

When changing mechanics, controls, stage flow, resources, scenes, scripts, or folders, update this file in the same work session. Keep the folder map and implementation notes accurate, and record new project-wide instructions here before applying them.

Keep development modular. Avoid large hard-coded dictionaries; use custom resources for editable stage, boss, upgrade, and unlock data. Give each boss its own script extending `BossRobot`, and keep its attack functions with that boss. The base class should own shared movement and health systems, with exported options for behaviors such as jumping, flash-stepping, and attack warning duration.

Add a short purpose comment above functions longer than 15 lines or with non-obvious behavior. Comment signal declarations and connection points so it is clear what emits each signal and what the connected handler does.
