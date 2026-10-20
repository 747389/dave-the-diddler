extends Node

## HelperFunctions emits this after gear totals change; the arena HUD and shop listen to refresh.
@warning_ignore("unused_signal")
signal gears_changed(total_gears: int, change: int)
## Emitted after an upgrade purchase so future UI or effects can react to its new level.
@warning_ignore("unused_signal")
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
## Emitted after an ability unlock so listeners can update ability availability.
@warning_ignore("unused_signal")
signal ability_unlocked(ability_id: StringName)

var gears: int = 0
var upgrade_levels: Dictionary = {}
var unlocked_abilities: Dictionary = {}
var stage_index: int = 0
var stage_cleared: bool = false
var game_complete: bool = false
var carried_player_health: float = -1.0
var bonus_air_dashes: int = 0
var stage_start_shield: float = 0.0


func _ready() -> void:
	# DataRegistry is an earlier autoload, so its resources are ready before state initialization.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for upgrade_id in DataRegistry.upgrades:
		upgrade_levels[upgrade_id] = 0
	for ability_id in DataRegistry.unlocks:
		unlocked_abilities[ability_id] = false
	HelperFunctions.ensure_input_actions()


func _input(event: InputEvent) -> void:
	# Keep global input routing thin; HelperFunctions owns restart-action behavior.
	HelperFunctions.handle_input(event)
