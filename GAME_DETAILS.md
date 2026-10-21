# Man Versus Machine — Game Details

This project targets Godot 4.7.2. The shared UI theme uses the supplied Chakra Petch font family from `other_assets/Chakra_Petch/`.

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
| 1 | Bolt, the Scrapper | 600 | Teleports through 50%, 80%, 90%, 95%, then 100% of a player-directed dash path in 0.02-second beats. Jump the damaging path. |
| 2 | Hopper, the Piston | 950 | Alternates a floor shockwave jump with an off-screen drop through a warned vertical pillar. |
| 3 | Ripsaw, the Cutter | 1,425 | Cycles radial volleys, five predictive sniper beams, and a 50-bullet gravity rain. |
| 4 | Bulwark, the Warden | 2,025 | Sends full-height shield walls through the arena. Dash through them during invulnerability frames. |
| 5 | Regent, the Machine Heart | 2,800 | Jumps and flash-steps between fast radial volleys and crossing walls. |

Boss health is five times the former stage value. Every major attack has a light red polygon warning around the boss. The default warning is 0.35 seconds and each stage resource can adjust it. Each boss has its own attack script; the shared `BossRobot` class handles health, movement, gravity, contact, optional jumping and flash-stepping, and attack timing.

## Controls

- Move: A/D or Left/Right arrow keys
- Jump: Space, W, or Up arrow
- Light attack: M1 (left mouse button)
- Heavy attack: M2 (right mouse button), sword only; sword M2 always deals its regular heavy-attack damage
- Swap weapons: Tab toggles between the default unlimited-ammo gun and the sword; the gun only fires its M1 shot
- Gun aim follows the mouse cursor; M1 fires toward the cursor. The gun has no M2 heavy attack; M2 is sword-only.
- Gun cooldown: 0.5 seconds; Double Shot fires two rounds and is a costly unlock
- Dash: Shift
- Special ability 1: Z (EMP Burst, unlock required)
- Special ability 2: X (Emergency Repair, unlock required)
- Special ability 3: C (Overdrive, unlock required)
- Interact with post-boss choices: E
- Pause/resume: Escape
- Restart from Bolt: Ctrl+R

## Combat and collision

- Sword M1 performs a light attack and sword M2 performs a heavy attack; both share a cooldown so alternating buttons cannot bypass it. There is no light-attack combo bonus. Gun M1 fires an unlimited-ammo shot every 0.5 seconds; each projectile independently has a 1% critical chance and deals 2x damage on a critical hit. Critical Targeting raises the chance by 1 percentage point per level to 10% over 9 levels. Overpressure Rounds raises critical damage by 0.2x per level to 4x over 10 levels. M2 does nothing while the gun is equipped.
- The base jump is lower than before to keep arena movement focused on the boss attacks.
- Dashing grants invulnerability for the dash plus a short recovery window. Overdrive grants a shorter invulnerability window on activation.
- During invulnerability, the player's collision layer is disabled so projectile and attack areas do not register a hit. The normal player layer is restored when invulnerability ends.
- Collision layer names are set in the project: Map is layer 1, Player is layer 2, Bosses is layer 3, and Attacks is layer 4. In Godot masks these correspond to bit values 1, 2, 4, and 8.
- Arena and test-map side walls use infinite `WorldBoundaryShape2D` planes, so the player cannot jump over a finite wall collider. Boss arenas and the movement test room have no traversal platforms. The tutorial retains its jump objective platform.
- The arena HUD places the player health bar and name on the left, and the boss health bar, numeric health, name, and attack detail on the right. Gear totals and control instructions are omitted during the fight.
- The player emits small gray square particles while running and jumping.
- Bolt stays in place between attacks, then creates one damaging Area2D across its teleported dash path. The five warp positions give its 0.1-second dash a visible deceleration.
- Hopper alternates a normal jump whose landing creates a floor-wide Area2D if the player is grounded, and an off-screen sky slam. The sky slam warns a full-height red column for 0.4 seconds before it becomes a damaging pillar. Both impacts use the shared `HelperFunctions.screen_shake` camera effect.
- Ripsaw cycles between its two radial volleys, five 0.4-second predictive sniper beam warnings followed by instantiated impact areas, and 50 upward bullets that fall with gravity.
- Bosses spawn on the arena floor at the start of every stage. The conveyor visual and its elevated spawn point have been removed.
- Tutorial step five advances when the player's world X position is greater than 550. Falling below the tutorial, arena, or movement-test map triggers a scene-authored fall sensor that returns the player to that scene's spawn and clears velocity/dash state.
- UI text uses the shared Chakra Petch theme. Input tips and boss names use reusable bold italic `LabelSettings` resources. UI scene roots and the tutorial canvas use the scene origin at (0, 0).

## Upgrades and shop

Stat upgrades include damage, movement speed, jump power, dash power, dash length, maximum health, attack speed, armor, Salvage Kit gear bonus, gun damage, gun fire rate, critical chance, and critical damage. Critical chance starts at 1% and upgrades to 10% over 9 levels. Critical damage starts at 2x and upgrades to 4x over 10 levels. Double Shot costs 250 gears. Prices grow by level and upgrades have level caps.

Ability unlocks include Double Jump, EMP Burst, Emergency Repair, and Overdrive (internal resource key: `overclock`). Upgrades and unlocks persist between human lives for the current game session; they are not saved after closing the game.

## Project structure

Scenes and scripts use matching gameplay categories:

- `scenes/player/` and `scripts/player/` — player scene, movement, combat, and abilities. Their `attacks/` subfolders contain player projectile scenes and scripts.
- `scenes/bosses/` and `scripts/bosses/` — boss scenes and one attack script per boss; `attacks/` contains reusable collision-shape attack construction; `minions/` is reserved for summons.
- `scenes/arenas/` and `scripts/world/` — arena scenes and world orchestration.
- `scenes/world/` and `scripts/world/` — reusable world systems, including the lower fall boundary.
- `scenes/tutorial/` and `scripts/tutorial/` — guided movement and combat practice.
- `scenes/ui/` and `scripts/ui/` — title screen, pause menu, shop, victory screen, and floating damage numbers.
- `scripts/autoload/` — `Global` run state and `DataRegistry` resource loading.
- `scripts/helpers/` — shared helper functions.
- `assets/ui/` — shared Chakra Petch theme and reusable bold italic label settings.
- `sounds/` and `shaders/` — project-root folders for audio and shader resources.
- `ART_STYLE.md` — palette, pixel-art rules, and reusable visual prompt guidance for consistent generated assets.
- `data/resource_scripts/` — custom resource types; `data/stages/`, `data/upgrades/`, and `data/unlocks/` — editable `.tres` definitions.

Each stage resource selects a boss scene and configures health, damage, attack interval, warning time, and optional jump or flash-step behavior. Keep boss-specific attack behavior in that boss's script. Prefer small reusable helpers and custom resources over large hard-coded dictionaries.

## Current implementation notes

- `project.godot` starts at the title screen and names the project Man Versus Machine.
- Title, pause, shop, victory, arena HUD, and tutorial HUD layouts are authored in their scene trees; scripts connect controls and update their state.
- `scenes/arenas/arena.tscn` contains the clear boss arena; it has a floor and world-boundary side walls, with no traversal platforms. The arena, tutorial, and movement test map return the player to their spawn if they fall below the lower boundary.
- The player starts with an unlimited-ammo gun. Tab swaps between gun and sword; gun damage, fire rate, critical chance, and critical damage are upgrades, while Double Shot costs 250 gears.
- The combat HUD shows player health and name on the left, and boss health with its numeric value, name, and attack detail on the right.
- Damage numbers spawn above the player when they take damage and above bosses or training targets when hit; each number rises, fades, and drifts to a randomized endpoint.
- `scenes/arenas/test_map.tscn` is a flat movement room with world-boundary side walls and a lower fall sensor.
- `scenes/tutorial/tutorial.tscn` teaches six ordered steps: move, jump to the platform, shoot an elevated target, switch to sword and land both light and heavy hits, jump-dash toward the gap and move past world X 550, then defeat a final target with any attack. The three dummy health values are exported and set to 30, 60, and 240; the shooting target is elevated and the final target is across the gap.
- `scenes/bosses/robot.tscn` is the shared boss body scene. Bolt, Hopper, Ripsaw, Bulwark, and Regent each have their own scene and script extending `BossRobot`.
- `scripts/bosses/attacks/boss_attack.gd` builds visible circular projectiles, ripple bars, and shield walls with matching collision shapes.
- Boss damage awards gears per applied hit, and each boss grants its clear bounty once.
- The post-boss arena offers only Repair / Refit Shop and next-stage choices. The repair button restores the carried frame for 20 gears.
- On death, stage progress resets to Bolt while gears and purchased technology persist for the next human.

## Project maintenance instruction

When changing mechanics, controls, stage flow, resources, scenes, scripts, or folders, update this file in the same work session. Keep the folder map and implementation notes accurate, and record new project-wide instructions here before applying them.

Keep development modular. Avoid large hard-coded dictionaries; use custom resources for editable stage, boss, upgrade, and unlock data. Give each boss its own script extending `BossRobot`, and keep its attack functions with that boss. The base class should own shared movement and health systems, with exported options for behaviors such as jumping, flash-stepping, and attack warning duration.

Build fixed UI elements and menus as nodes in their `.tscn` scenes. Keep scripts responsible for behavior, state updates, and data-driven content; do not create a whole menu or fixed HUD tree in `_ready()`.

Add a short purpose comment above functions longer than 15 lines or with non-obvious behavior. Comment signal declarations and connection points so it is clear what emits each signal and what the connected handler does.
