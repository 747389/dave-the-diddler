extends Control

var _gear_label: Label
var _upgrade_list: VBoxContainer
var _unlock_list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_shop()
	# Global emits this after purchases or service rewards; refresh both shop columns.
	Global.gears_changed.connect(_refresh_shop)
	_refresh_shop()


## Construct the two-column upgrade shop and connect all action buttons.
func _build_shop() -> void:
	# Compose the shop UI at runtime and route its buttons to purchase/continue handlers.
	var background := ColorRect.new()
	background.color = Color(0.055, 0.075, 0.11, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "REFIT BAY  //  ROBOT %02d OF %02d" % [
		Global.stage_index + 1,
		HelperFunctions.get_stage_count()
	]
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gear_label = Label.new()
	_gear_label.add_theme_font_size_override("font_size", 22)
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_gear_label)

	var subtitle := Label.new()
	if Global.stage_cleared:
		subtitle.text = "Stage cleared. Spend your gears, then continue to the next arena."
	else:
		subtitle.text = "Run over. Spend salvaged gears, then retry this robot."
	layout.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	layout.add_child(columns)
	_upgrade_list = _make_column(columns, "UPGRADES")
	_unlock_list = _make_column(columns, "UNLOCKS")

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	var restart_button := Button.new()
	restart_button.text = "Restart arena  (Ctrl + R)"
	# Button presses call the shared run reset or the stage-aware continuation handler.
	restart_button.pressed.connect(HelperFunctions.restart_run)
	footer.add_child(restart_button)
	var continue_button := Button.new()
	if not Global.stage_cleared:
		continue_button.text = "Retry Robot %d" % [Global.stage_index + 1]
	elif Global.stage_index == HelperFunctions.get_stage_count() - 1:
		continue_button.text = "Finish the five-robot run"
	else:
		continue_button.text = "Continue to Robot %d" % [Global.stage_index + 2]
	continue_button.pressed.connect(_start_arena)
	footer.add_child(continue_button)


## Add a titled scrollable shop column and return its card container.
func _make_column(parent: HBoxContainer, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	return entries


func _refresh_shop(_unused_value: Variant = null, _unused_change: int = 0) -> void:
	# Rebuild cards from current resource definitions so labels and purchase states stay fresh.
	_gear_label.text = "⚙  %d GEARS" % Global.gears
	_clear_entries(_upgrade_list)
	_clear_entries(_unlock_list)
	for upgrade_id in DataRegistry.upgrades:
		_add_upgrade_card(upgrade_id)
	for ability_id in DataRegistry.unlocks:
		_add_unlock_card(ability_id)


## Show one upgrade's current level, next price, and purchase action.
func _add_upgrade_card(upgrade_id: StringName) -> void:
	# Derive status, price, and purchase availability from the shared upgrade helpers.
	var definition := HelperFunctions.get_upgrade_definition(upgrade_id)
	var level := HelperFunctions.get_upgrade_level(upgrade_id)
	var cost := HelperFunctions.get_next_upgrade_cost(upgrade_id)
	var card := _make_card(
		str(definition.get("name", upgrade_id)),
		str(definition.get("description", "")),
		"Level %d / %d" % [level, int(definition.get("max_level", 0))]
	)
	var button := Button.new()
	button.text = "MAX LEVEL" if cost < 0 else "Upgrade · %d gears" % cost
	button.disabled = cost < 0 or not HelperFunctions.can_purchase_upgrade(upgrade_id)
	button.pressed.connect(_buy_upgrade.bind(upgrade_id))
	card.add_child(button)
	_upgrade_list.add_child(card)


## Show one ability unlock and disable the button once it is owned or unaffordable.
func _add_unlock_card(ability_id: StringName) -> void:
	# Unlocked abilities stay visible but their purchase buttons are disabled.
	var definition := HelperFunctions.get_unlock_definition(ability_id)
	var unlocked := HelperFunctions.is_ability_unlocked(ability_id)
	var card := _make_card(
		str(definition.get("name", ability_id)),
		str(definition.get("description", "")),
		"Unlocked" if unlocked else "Ability"
	)
	var button := Button.new()
	button.text = "UNLOCKED" if unlocked else "Unlock · %d gears" % int(definition.get("cost", 0))
	button.disabled = unlocked or not HelperFunctions.can_purchase_unlock(ability_id)
	button.pressed.connect(_buy_unlock.bind(ability_id))
	card.add_child(button)
	_unlock_list.add_child(card)


func _make_card(title_text: String, description: String, status: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.text = "%s   ·   %s" % [title_text, status]
	title.add_theme_font_size_override("font_size", 16)
	card.add_child(title)
	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(detail)
	return card


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


func _start_arena() -> void:
	# A cleared final stage exits to victory; other clears advance, while deaths retry.
	if Global.stage_cleared:
		if Global.stage_index == HelperFunctions.get_stage_count() - 1:
			Global.game_complete = true
			get_tree().change_scene_to_file("res://scenes/ui/victory.tscn")
			return
		HelperFunctions.advance_stage()
	else:
		Global.carried_player_health = -1.0
	get_tree().change_scene_to_file("res://scenes/arenas/arena.tscn")
