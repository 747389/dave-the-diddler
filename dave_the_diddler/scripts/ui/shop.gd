extends Control

const FRAME_REPAIR_COST: int = 20
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop_card.tscn")

@onready var _gear_label: Label = $Margin/Layout/Header/GearLabel
@onready var _title_label: Label = $Margin/Layout/Header/Title
@onready var _subtitle: Label = $Margin/Layout/Subtitle
@onready var _upgrade_list: VBoxContainer = $Margin/Layout/Columns/UpgradePanel/UpgradeContent/UpgradeScroll/UpgradeEntries
@onready var _unlock_list: VBoxContainer = $Margin/Layout/Columns/UnlockPanel/UnlockContent/UnlockScroll/UnlockEntries
@onready var _repair_button: Button = $Margin/Layout/Footer/RepairButton
@onready var _restart_button: Button = $Margin/Layout/Footer/RestartButton
@onready var _continue_button: Button = $Margin/Layout/Footer/ContinueButton


func _ready() -> void:
	Global.gears += 10000
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The scene owns the fixed layout; these buttons call purchase and stage-flow actions.
	_restart_button.pressed.connect(HelperFunctions.restart_run)
	_repair_button.pressed.connect(_repair_frame)
	_continue_button.pressed.connect(_start_arena)
	_repair_button.visible = Global.stage_cleared
	_title_label.text = "REFIT BAY  //  ROBOT %02d OF %02d" % [
		Global.stage_index + 1,
		HelperFunctions.get_stage_count()
	]
	_restart_button.text = "Restart from Bolt  (Ctrl + R)"
	if Global.stage_cleared:
		_subtitle.text = "Stage cleared. Repair your frame, refit, then move to the next arena."
	else:
		_subtitle.text = "A human fell. The machine rebuilds; their gears and technology carry forward."
	if not Global.stage_cleared:
		_continue_button.text = "Deploy against Bolt"
	elif Global.stage_index == HelperFunctions.get_stage_count() - 1:
		_continue_button.text = "Finish the five-robot run"
	else:
		_continue_button.text = "Continue to Robot %d" % [Global.stage_index + 2]
	# Global emits this after purchases or service rewards; refresh both shop columns.
	Global.gears_changed.connect(_refresh_shop)
	_refresh_shop()


func _refresh_shop(_unused_value: Variant = null, _unused_change: int = 0) -> void:
	# Rebuild cards from current resource definitions so labels and purchase states stay fresh.
	_gear_label.text = "⚙  %d GEARS" % Global.gears
	_clear_entries(_upgrade_list)
	_clear_entries(_unlock_list)
	for upgrade_id in DataRegistry.upgrades:
		_add_upgrade_card(upgrade_id)
	for ability_id in DataRegistry.unlocks:
		_add_unlock_card(ability_id)
	if is_instance_valid(_repair_button):
		var maximum_health := 100.0 + HelperFunctions.get_upgrade_value(&"max_health")
		_repair_button.disabled = (
			Global.gears < FRAME_REPAIR_COST
			or Global.carried_player_health >= maximum_health
		)


## Show one upgrade's current level, next price, and purchase action.
func _add_upgrade_card(upgrade_id: StringName) -> void:
	# Derive status, price, and purchase availability from the shared upgrade helpers.
	var definition := HelperFunctions.get_upgrade_definition(upgrade_id)
	var level := HelperFunctions.get_upgrade_level(upgrade_id)
	var cost := HelperFunctions.get_next_upgrade_cost(upgrade_id)
	var card := SHOP_CARD_SCENE.instantiate() as ShopCard
	card.configure(
		str(definition.get("name", upgrade_id)),
		str(definition.get("description", "")),
		"Level %d / %d" % [level, int(definition.get("max_level", 0))],
		"MAX LEVEL" if cost < 0 else "Upgrade · %d gears" % cost,
		cost < 0 or not HelperFunctions.can_purchase_upgrade(upgrade_id),
		upgrade_id
	)
	card.action_pressed.connect(_buy_upgrade)
	_upgrade_list.add_child(card)


## Show one ability unlock and disable the button once it is owned or unaffordable.
func _add_unlock_card(ability_id: StringName) -> void:
	# Unlocked abilities stay visible but their purchase buttons are disabled.
	var definition := HelperFunctions.get_unlock_definition(ability_id)
	var unlocked := HelperFunctions.is_ability_unlocked(ability_id)
	var card := SHOP_CARD_SCENE.instantiate() as ShopCard
	card.configure(
		str(definition.get("name", ability_id)),
		str(definition.get("description", "")),
		"Unlocked" if unlocked else "Ability",
		"UNLOCKED" if unlocked else "Unlock · %d gears" % int(definition.get("cost", 0)),
		unlocked or not HelperFunctions.can_purchase_unlock(ability_id),
		ability_id
	)
	card.action_pressed.connect(_buy_unlock)
	_unlock_list.add_child(card)


func _clear_entries(entries: VBoxContainer) -> void:
	# Detach before queue_free so rebuilding the UI does not retain stale cards.
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()


func _buy_upgrade(upgrade_id: StringName) -> void:
	if not HelperFunctions.purchase_upgrade(upgrade_id):
		_refresh_shop()


func _buy_unlock(ability_id: StringName) -> void:
	if not HelperFunctions.purchase_unlock(ability_id):
		_refresh_shop()


func _repair_frame() -> void:
	var maximum_health := 100.0 + HelperFunctions.get_upgrade_value(&"max_health")
	if Global.gears < FRAME_REPAIR_COST or Global.carried_player_health >= maximum_health:
		return
	Global.gears -= FRAME_REPAIR_COST
	Global.carried_player_health = maximum_health
	Global.gears_changed.emit(Global.gears, -FRAME_REPAIR_COST)


func _start_arena() -> void:
	# Cleared stages advance, the final clear exits, and a death deploys the next human at Bolt.
	if Global.stage_cleared:
		if Global.stage_index == HelperFunctions.get_stage_count() - 1:
			Global.game_complete = true
			get_tree().change_scene_to_file("res://scenes/ui/victory.tscn")
			return
		HelperFunctions.advance_stage()
	else:
		Global.carried_player_health = -1.0
	get_tree().change_scene_to_file("res://scenes/arenas/arena.tscn")
