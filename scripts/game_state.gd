extends Node

signal gears_changed(total_gears: int, change: int)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
signal ability_unlocked(ability_id: StringName)

const UPGRADE_DEFINITIONS: Dictionary = {
	&"damage": {
		"name": "Damage",
		"description": "Increase damage dealt to robots.",
		"effect_type": "multiplier",
		"effect_per_level": 0.15,
		"base_cost": 10,
		"cost_growth": 1.45,
		"max_level": 10
	},
	&"speed": {
		"name": "Movement Speed",
		"description": "Move faster around the arena.",
		"effect_type": "multiplier",
		"effect_per_level": 0.08,
		"base_cost": 8,
		"cost_growth": 1.4,
		"max_level": 10
	},
	&"jump": {
		"name": "Jump Power",
		"description": "Jump higher to reach more platforms.",
		"effect_type": "multiplier",
		"effect_per_level": 0.08,
		"base_cost": 8,
		"cost_growth": 1.4,
		"max_level": 10
	},
	&"dash": {
		"name": "Dash Power",
		"description": "Increase dash speed.",
		"effect_type": "multiplier",
		"effect_per_level": 0.12,
		"base_cost": 10,
		"cost_growth": 1.45,
		"max_level": 10
	},
	&"dash_length": {
		"name": "Dash Length",
		"description": "Stay in a dash for longer.",
		"effect_type": "multiplier",
		"effect_per_level": 0.12,
		"base_cost": 10,
		"cost_growth": 1.45,
		"max_level": 10
	},
	&"max_health": {
		"name": "Reinforced Frame",
		"description": "Increase maximum health.",
		"effect_type": "bonus",
		"effect_per_level": 20.0,
		"base_cost": 12,
		"cost_growth": 1.45,
		"max_level": 10
	},
	&"attack_speed": {
		"name": "Attack Speed",
		"description": "Attack more often.",
		"effect_type": "multiplier",
		"effect_per_level": 0.08,
		"base_cost": 12,
		"cost_growth": 1.45,
		"max_level": 10
	},
	&"armor": {
		"name": "Armor",
		"description": "Reduce damage taken from robots.",
		"effect_type": "bonus",
		"effect_per_level": 0.04,
		"base_cost": 12,
		"cost_growth": 1.5,
		"max_level": 10
	},
	&"gear_bonus": {
		"name": "Salvage Kit",
		"description": "Find extra gears for every hit you land.",
		"effect_type": "bonus",
		"effect_per_level": 1.0,
		"base_cost": 15,
		"cost_growth": 1.5,
		"max_level": 5
	}
}

const UNLOCK_DEFINITIONS: Dictionary = {
	&"double_jump": {
		"name": "Double Jump",
		"description": "Jump again while airborne.",
		"cost": 20
	},
	&"emp": {
		"name": "EMP Burst (Z)",
		"description": "Damage nearby robots with an electrical pulse.",
		"cost": 25
	},
	&"repair": {
		"name": "Emergency Repair (X)",
		"description": "Restore 40 health. Cannot exceed max health.",
		"cost": 20
	},
	&"overclock": {
		"name": "Overclock (C)",
		"description": "Move faster for a short time.",
		"cost": 30
	}
}

const STAGE_DEFINITIONS: Array[Dictionary] = [
	{
		"name": "Bolt, the Scrapper",
		"title": "STAGE 1 // THE SCRAP PIT",
		"health": 120.0,
		"speed": 86.0,
		"contact_damage": 12.0,
		"gear_reward": 16,
		"ability": "Shoulder charge",
		"arena_color": Color(0.055, 0.075, 0.11),
		"service_id": &"repair",
		"service_title": "Repair Station",
		"service_hint": "Restore your health"
	},
	{
		"name": "Hopper, the Piston",
		"title": "STAGE 2 // VERTICAL FOUNDRY",
		"health": 190.0,
		"speed": 68.0,
		"contact_damage": 15.0,
		"gear_reward": 22,
		"ability": "Leaps and landing shockwaves",
		"arena_color": Color(0.09, 0.06, 0.12),
		"service_id": &"salvage",
		"service_title": "Salvage Cache",
		"service_hint": "Collect 30 gears"
	},
	{
		"name": "Ripsaw, the Cutter",
		"title": "STAGE 3 // SHEAR WORKS",
		"health": 285.0,
		"speed": 76.0,
		"contact_damage": 18.0,
		"gear_reward": 30,
		"ability": "Fires three spinning cutters",
		"arena_color": Color(0.045, 0.105, 0.12),
		"service_id": &"dash_charge",
		"service_title": "Dash Recharger",
		"service_hint": "Refresh your dash"
	},
	{
		"name": "Bulwark, the Warden",
		"title": "STAGE 4 // SHIELD VAULT",
		"health": 405.0,
		"speed": 54.0,
		"contact_damage": 21.0,
		"gear_reward": 42,
		"ability": "Raises a damage-reducing shield",
		"arena_color": Color(0.1, 0.075, 0.04),
		"service_id": &"shield",
		"service_title": "Shield Projector",
		"service_hint": "Reduce damage for the next fight"
	},
	{
		"name": "Regent, the Machine Heart",
		"title": "STAGE 5 // THE CORE CHAMBER",
		"health": 560.0,
		"speed": 74.0,
		"contact_damage": 25.0,
		"gear_reward": 60,
		"ability": "Charges, leaps, and launches scrap drones",
		"arena_color": Color(0.12, 0.035, 0.07),
		"service_id": &"repair",
		"service_title": "Last Repair Station",
		"service_hint": "Restore your health before the final fight"
	}
]

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	for upgrade_id in UPGRADE_DEFINITIONS:
		upgrade_levels[upgrade_id] = 0
	for ability_id in UNLOCK_DEFINITIONS:
		unlocked_abilities[ability_id] = false
	_ensure_input_actions()


func add_gears(amount: int) -> bool:
	if amount <= 0:
		return false

	gears += amount
	gears_changed.emit(gears, amount)
	return true


func award_damage_gears(damage: float) -> int:
	if damage <= 0.0:
		return 0
	var salvage_bonus := int(get_upgrade_value(&"gear_bonus"))
	var reward := maxi(1, ceili(damage / 10.0)) + salvage_bonus
	add_gears(reward)
	return reward


func get_upgrade_level(upgrade_id: StringName) -> int:
	if not UPGRADE_DEFINITIONS.has(upgrade_id):
		return 0
	return int(upgrade_levels.get(upgrade_id, 0))


func get_upgrade_definition(upgrade_id: StringName) -> Dictionary:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	return definition.duplicate(true)


func get_upgrade_value(upgrade_id: StringName) -> float:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	if definition.is_empty():
		return 0.0

	var level := get_upgrade_level(upgrade_id)
	var effect_per_level := float(definition.get("effect_per_level", 0.0))
	if definition.get("effect_type", "") == "multiplier":
		return 1.0 + level * effect_per_level
	return level * effect_per_level


func get_next_upgrade_cost(upgrade_id: StringName) -> int:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	if definition.is_empty():
		return -1

	var level := get_upgrade_level(upgrade_id)
	if level >= int(definition.get("max_level", 0)):
		return -1

	var base_cost := float(definition.get("base_cost", 0))
	var cost_growth := float(definition.get("cost_growth", 1.0))
	return maxi(1, ceili(base_cost * pow(cost_growth, level)))


func can_purchase_upgrade(upgrade_id: StringName) -> bool:
	var cost := get_next_upgrade_cost(upgrade_id)
	return cost > 0 and gears >= cost


func purchase_upgrade(upgrade_id: StringName) -> bool:
	var cost := get_next_upgrade_cost(upgrade_id)
	if cost <= 0 or gears < cost:
		return false

	gears -= cost
	var new_level := get_upgrade_level(upgrade_id) + 1
	upgrade_levels[upgrade_id] = new_level
	gears_changed.emit(gears, -cost)
	upgrade_purchased.emit(upgrade_id, new_level)
	return true


func is_ability_unlocked(ability_id: StringName) -> bool:
	return bool(unlocked_abilities.get(ability_id, false))


func get_unlock_definition(ability_id: StringName) -> Dictionary:
	var definition: Dictionary = UNLOCK_DEFINITIONS.get(ability_id, {})
	return definition.duplicate(true)


func can_purchase_unlock(ability_id: StringName) -> bool:
	var definition: Dictionary = UNLOCK_DEFINITIONS.get(ability_id, {})
	return (
		not definition.is_empty()
		and not is_ability_unlocked(ability_id)
		and gears >= int(definition.get("cost", 0))
	)


func purchase_unlock(ability_id: StringName) -> bool:
	if not can_purchase_unlock(ability_id):
		return false

	var definition: Dictionary = UNLOCK_DEFINITIONS[ability_id]
	var cost := int(definition.get("cost", 0))
	gears -= cost
	unlocked_abilities[ability_id] = true
	gears_changed.emit(gears, -cost)
	ability_unlocked.emit(ability_id)
	return true


func restart_run() -> void:
	get_tree().paused = false
	stage_index = 0
	stage_cleared = false
	game_complete = false
	carried_player_health = -1.0
	bonus_air_dashes = 0
	stage_start_shield = 0.0
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart_run()


func _ensure_input_actions() -> void:
	if not InputMap.has_action(&"pause"):
		InputMap.add_action(&"pause")
	if not InputMap.has_action(&"restart"):
		InputMap.add_action(&"restart")
	var pause_event := InputEventKey.new()
	pause_event.physical_keycode = KEY_ESCAPE
	if not InputMap.action_has_event(&"pause", pause_event):
		InputMap.action_add_event(&"pause", pause_event)
	var restart_event := InputEventKey.new()
	restart_event.physical_keycode = KEY_R
	restart_event.ctrl_pressed = true
	if not InputMap.action_has_event(&"restart", restart_event):
		InputMap.action_add_event(&"restart", restart_event)
	if not InputMap.has_action(&"interact"):
		InputMap.add_action(&"interact")
	var interact_event := InputEventKey.new()
	interact_event.physical_keycode = KEY_E
	if not InputMap.action_has_event(&"interact", interact_event):
		InputMap.action_add_event(&"interact", interact_event)


func get_stage_definition(index: int = -1) -> Dictionary:
	var requested_index := stage_index if index < 0 else index
	if requested_index < 0 or requested_index >= STAGE_DEFINITIONS.size():
		return {}
	return STAGE_DEFINITIONS[requested_index].duplicate(true)


func mark_stage_cleared() -> void:
	stage_cleared = true


func advance_stage() -> bool:
	if not stage_cleared or stage_index >= STAGE_DEFINITIONS.size() - 1:
		return false
	stage_index += 1
	stage_cleared = false
	return true
