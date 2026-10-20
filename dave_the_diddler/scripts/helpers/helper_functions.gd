class_name HelperFunctions
extends RefCounted


static func add_gears(amount: int) -> bool:
	if amount <= 0:
		return false

	Global.gears += amount
	# All gear displays subscribe to this signal through their scene scripts.
	Global.gears_changed.emit(Global.gears, amount)
	return true


static func award_damage_gears(damage: float) -> int:
	if damage <= 0.0:
		return 0
	var salvage_bonus := int(get_upgrade_value(&"gear_bonus"))
	var reward := maxi(1, ceili(damage / 10.0)) + salvage_bonus
	add_gears(reward)
	return reward


static func get_upgrade_level(upgrade_id: StringName) -> int:
	if not DataRegistry.upgrades.has(upgrade_id):
		return 0
	return int(Global.upgrade_levels.get(upgrade_id, 0))


static func get_upgrade_definition(upgrade_id: StringName) -> Dictionary:
	# Keep the shop's display data independent from the editable resource object.
	var definition := DataRegistry.upgrades.get(upgrade_id) as UpgradeData
	if definition == null:
		return {}
	return {
		"name": definition.display_name,
		"description": definition.description,
		"effect_type": definition.effect_type,
		"effect_per_level": definition.effect_per_level,
		"base_cost": definition.base_cost,
		"cost_growth": definition.cost_growth,
		"max_level": definition.max_level
	}


static func get_upgrade_value(upgrade_id: StringName) -> float:
	# Multiplier upgrades start at 1.0; bonus upgrades start at 0.0.
	var definition := DataRegistry.upgrades.get(upgrade_id) as UpgradeData
	if definition == null:
		return 0.0

	var level := get_upgrade_level(upgrade_id)
	if definition.effect_type == "multiplier":
		return 1.0 + level * definition.effect_per_level
	return level * definition.effect_per_level


static func get_next_upgrade_cost(upgrade_id: StringName) -> int:
	# Return -1 when the upgrade is unknown or has reached its configured cap.
	var definition := DataRegistry.upgrades.get(upgrade_id) as UpgradeData
	if definition == null:
		return -1

	var level := get_upgrade_level(upgrade_id)
	if level >= definition.max_level:
		return -1
	return maxi(1, ceili(definition.base_cost * pow(definition.cost_growth, level)))


static func can_purchase_upgrade(upgrade_id: StringName) -> bool:
	var cost := get_next_upgrade_cost(upgrade_id)
	return cost > 0 and Global.gears >= cost


static func purchase_upgrade(upgrade_id: StringName) -> bool:
	# Recheck price and balance here so a stale shop button cannot spend invalidly.
	var cost := get_next_upgrade_cost(upgrade_id)
	if cost <= 0 or Global.gears < cost:
		return false

	Global.gears -= cost
	var new_level := get_upgrade_level(upgrade_id) + 1
	Global.upgrade_levels[upgrade_id] = new_level
	# The shop listens to gears_changed; upgrade_purchased is available for upgrade-specific listeners.
	Global.gears_changed.emit(Global.gears, -cost)
	Global.upgrade_purchased.emit(upgrade_id, new_level)
	return true


static func is_ability_unlocked(ability_id: StringName) -> bool:
	return bool(Global.unlocked_abilities.get(ability_id, false))


static func get_unlock_definition(ability_id: StringName) -> Dictionary:
	# Convert the resource to the small dictionary shape consumed by shop cards.
	var definition := DataRegistry.unlocks.get(ability_id) as UnlockData
	if definition == null:
		return {}
	return {
		"name": definition.display_name,
		"description": definition.description,
		"cost": definition.cost
	}


static func can_purchase_unlock(ability_id: StringName) -> bool:
	# Unlocks are one-time purchases and require both a valid entry and enough gears.
	var definition := DataRegistry.unlocks.get(ability_id) as UnlockData
	return (
		definition != null
		and not is_ability_unlocked(ability_id)
		and Global.gears >= definition.cost
	)


static func purchase_unlock(ability_id: StringName) -> bool:
	# Validate before mutating state, then notify gear and ability listeners.
	if not can_purchase_unlock(ability_id):
		return false

	var definition := DataRegistry.unlocks.get(ability_id) as UnlockData
	Global.gears -= definition.cost
	Global.unlocked_abilities[ability_id] = true
	# The shop listens to gears_changed; ability_unlocked is available for ability-specific listeners.
	Global.gears_changed.emit(Global.gears, -definition.cost)
	Global.ability_unlocked.emit(ability_id)
	return true


static func restart_run() -> void:
	# Restart preserves purchased upgrades and gears, but resets stage-specific run state.
	Global.get_tree().paused = false
	Global.stage_index = 0
	Global.stage_cleared = false
	Global.game_complete = false
	Global.carried_player_health = -1.0
	Global.bonus_air_dashes = 0
	Global.stage_start_shield = 0.0
	Global.get_tree().change_scene_to_file("res://scenes/arenas/arena.tscn")


## Start a fresh campaign with no carried run state or purchases.
static func start_new_run() -> void:
	_reset_run_progress()
	Global.get_tree().paused = false
	Global.get_tree().change_scene_to_file("res://scenes/arenas/arena.tscn")


## Start the training map with baseline stats so its instructions match the controls.
static func start_tutorial() -> void:
	_reset_run_progress()
	Global.get_tree().paused = false
	Global.get_tree().change_scene_to_file("res://scenes/tutorial/tutorial.tscn")


static func _reset_run_progress() -> void:
	Global.gears = 0
	Global.stage_index = 0
	Global.stage_cleared = false
	Global.game_complete = false
	Global.carried_player_health = -1.0
	Global.bonus_air_dashes = 0
	Global.stage_start_shield = 0.0
	for upgrade_id in Global.upgrade_levels:
		Global.upgrade_levels[upgrade_id] = 0
	for ability_id in Global.unlocked_abilities:
		Global.unlocked_abilities[ability_id] = false


## Add required global actions and bindings without replacing project-defined events.
static func ensure_input_actions() -> void:
	# Add only missing actions and key events so project-defined bindings stay intact.
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


static func handle_input(event: InputEvent) -> void:
	# The autoload forwards restart input here so the state node only routes events.
	if event.is_action_pressed(&"restart"):
		restart_run()


static func get_stage_count() -> int:
	return DataRegistry.stages.size()


## Return a stage resource in campaign order for scene and boss configuration.
static func get_stage_resource(index: int = -1) -> StageData:
	var requested_index := Global.stage_index if index < 0 else index
	var stage_resources: Array[StageData] = []
	for resource in DataRegistry.stages.values():
		var stage_resource := resource as StageData
		if stage_resource != null:
			stage_resources.append(stage_resource)
	stage_resources.sort_custom(_sort_stage_data)
	if requested_index < 0 or requested_index >= stage_resources.size():
		return null
	return stage_resources[requested_index]


static func mark_stage_cleared() -> void:
	Global.stage_cleared = true


static func advance_stage() -> bool:
	# Only a cleared stage can advance, and the final stage has no next stage.
	if not Global.stage_cleared or Global.stage_index >= get_stage_count() - 1:
		return false
	Global.stage_index += 1
	Global.stage_cleared = false
	return true


static func _sort_stage_data(first: StageData, second: StageData) -> bool:
	return first.order < second.order
