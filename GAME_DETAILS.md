# Man Versus Machine — Game Details

This project targets Godot 4.7.2.

## Game concept

A one-week game jam game with the theme **Man Versus Machine**. The player takes on five robots, one per stage, earns gears from damaging and defeating them, and spends gears on upgrades and ability unlocks. The run is complete after all five robots are defeated.

## Stage flow

1. Enter the current robot's arena. Only that stage boss is a robot in the arena at a time.
2. Damage the boss to earn gears. Each damaging hit awards `ceil(actual HP damage / 10)` gears, with a minimum of one; the Salvage Kit adds gears to each hit.
3. Defeat the boss to collect its clear bounty. Three platforms slide in from the arena sides: a refit shop, a stage-specific service, and a gate to the next stage (or the victory screen after Stage 5).
4. Press E near a platform to use it. Health carries between cleared stages. After the player dies, the shop opens and Continue retries that same robot.
5. Defeat the fifth robot and use the exit platform, or visit the refit shop and finish the run there.

Boss projectiles and impact effects are hazards, not extra robot actors. The only robot in each fight is its current boss.

## The five robots

| Stage | Robot | Health | Contact damage | Clear bounty | Ability | Arena |
|---|---|---:|---:|---:|---|---|
| 1 | Bolt, the Scrapper | 120 | 12 | 16 | Shoulder charge | Scrap Pit, open floor |
| 2 | Hopper, the Piston | 190 | 15 | 22 | Leaps and landing shockwaves, with a highlighted landing lane | Vertical Foundry, staggered platforms |
| 3 | Ripsaw, the Cutter | 285 | 18 | 30 | Fires three spinning cutters | Shear Works, stepped platforms |
| 4 | Bulwark, the Warden | 405 | 21 | 42 | Timed shield with an activation flash and a telegraphed ground slam | Shield Vault, separated ledges |
| 5 | Regent, the Machine Heart | 560 | 25 | 60 | Charges, leaps, and launches a fan of scrap drones | Core Chamber, final platform layout |

Boss health rises at every stage. Each stage also changes the arena tint and platform arrangement. Boss stats and stage services are stored in custom resources under data/stages/ and loaded through the DataRegistry autoload.

## Between-stage platform interactions

- **Refit Shop:** buy stat upgrades or ability unlocks.
- **Repair Station:** restore health for the next stage.
- **Salvage Cache:** collect 30 gears.
- **Dash Recharger:** gain one extra air dash for the next stage.
- **Shield Projector:** reduce damage for the next stage.
- **Exit / Victory:** finish after defeating Stage 5.

The service platform changes by stage. The shop is on the left, the service platform in the middle, and the stage gate on the right.

## Controls

- Move: A/D or Left/Right arrow keys
- Jump: Space, W, or Up arrow
- Attack: F
- Dash: Q
- Special ability 1: Z (EMP Burst, unlock required)
- Special ability 2: X (Emergency Repair, unlock required)
- Special ability 3: C (Overclock, unlock required)
- Interact with post-boss platforms: E
- Pause/resume: Escape
- Restart from Stage 1: Ctrl+R

## Upgrade shop

Stat upgrades are in the left column: damage, movement speed, jump power, dash power, dash length, max health, attack speed, armor, and Salvage Kit gear bonus. Prices grow by level and upgrades have level caps.

Ability unlocks are in the right column: Double Jump, EMP Burst, Emergency Repair, and Overclock. Unlocks are separate from stat upgrades and are purchased once.

## Project structure

Scenes and scripts use matching gameplay categories:

- scenes/player/ and scripts/player/ — player scene and movement, combat, and abilities.
- scenes/bosses/ and scripts/bosses/ — boss scene and behavior. attacks/ contains boss projectiles; minions/ is reserved for future boss summons.
- scenes/arenas/ — the campaign arena and movement test map.
- scenes/tutorial/ and scripts/tutorial/ — guided tutorial and training dummy.
- scenes/world/ and scripts/world/ — arena orchestration and world interactions; intermission/ contains between-stage platforms.
- scenes/ui/ and scripts/ui/ — title screen, pause menu, shop, and victory screen.
- scripts/autoload/ — Global run state and DataRegistry resource loading.
- scripts/helpers/ — shared helper functions.
- data/resource_scripts/ — custom resource formats; data/stages/, data/upgrades/, and data/unlocks/ — editable .tres definitions.

Key scenes:

- scenes/ui/title_screen.tscn — startup screen with campaign, training, and quit options.
- scenes/arenas/arena.tscn — stage arena with polygon walls, conveyor entrance, player, and boss setup.
- scenes/player/player.tscn — player body, collision, camera, and attack area.
- scenes/bosses/robot.tscn — current stage boss configured from stage data.
- scenes/bosses/attacks/scrap_projectile.tscn — non-robot ranged hazard used by later bosses.
- scenes/world/intermission/intermission_platform.tscn — physical platform and E interaction area.
- scenes/ui/shop.tscn — post-death and intermission shop.
- scenes/ui/victory.tscn — completion screen after all five robots are defeated.
- scenes/arenas/test_map.tscn — movement test room.
- scenes/tutorial/tutorial.tscn — separate guided movement, jump, and attack practice map.
- scenes/ui/pause_menu.tscn — shared pause, return-to-title, and quit menu.

Key scripts:

- scripts/world/arena.gd — stage layouts, boss setup, HUD, pause, platforms, and stage transitions.
- scripts/player/player.gd — movement, health, attack, dash, and unlocked special abilities.
- scripts/bosses/robot.gd — boss stats, stage-specific attack patterns, health, and damage rewards.
- scripts/bosses/attacks/scrap_projectile.gd — boss projectile movement and player damage.
- scripts/world/intermission/intermission_platform.gd — post-boss platform interaction signals.
- scripts/ui/shop.gd — separate upgrade and unlock columns.
- scripts/autoload/global.gd — global gears, upgrades, unlocks, stage progression, and restart state (Global autoload).
- scripts/autoload/data_registry.gd — loads stage, upgrade, and unlock resources.
- scripts/helpers/helper_functions.gd — shared scene and run helper functions.
- scripts/tutorial/tutorial.gd — tutorial objectives, HUD, and progression.
## Current implementation notes

- scenes/ui/title_screen.tscn is the project's startup scene.
- The title screen offers campaign, training, and quit options. The shared pause menu offers resume, return to title, and quit.
- scenes/tutorial/tutorial.tscn is a separate objective-based practice map: move to a marker, jump onto a raised platform, then attack the training dummy until it is defeated.
- The arena uses polygon placeholders and code-generated platforms; no art or sound assets are in use yet.
- Damage rewards are granted on each successful boss hit, then a separate bounty is granted on defeat.
- Hopper shows a ground lane before jumping to mark its landing shockwave, then releases a gold shockwave ring and debris particles on impact.
- Bulwark pauses for a short red radius warning before its ground slam; the slam releases a ring and debris particles. Its shield activation has a blue flash and particles.
- Gear, upgrade, unlock, and stage state persist between scene changes for the current game session. They are not saved after closing the game.
- Boss stats, stages, upgrades, and unlocks are editable custom .tres resources loaded by DataRegistry.

## Project maintenance instruction

When changing game mechanics, controls, stage flow, resources, scenes, scripts, or folder layout, update this file in the same work session so it stays aligned with the project. Keep the folder map and implementation notes current, and record new project-wide coding or asset instructions here before applying them across the project.

For code comments, add a short purpose comment above functions that exceed 15 lines or have non-obvious behavior. Comment signal declarations and connection points so it is clear what emits each signal and what the connected handler does.



