extends Node2D

const PLATFORM_SCENE: PackedScene = preload("res://scenes/world/intermission/intermission_platform.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

@onready var player: Player = $Player
@onready var conveyor_mouth: Marker2D = $Conveyor/Mouth
@onready var background: Polygon2D = $Background
@onready var floor_visual: Polygon2D = $Floor/Visual
@onready var left_wall_visual: Polygon2D = $LeftWall/Visual
@onready var right_wall_visual: Polygon2D = $RightWall/Visual
@onready var conveyor_visual: Polygon2D = $Conveyor/Belt

var _boss: BossRobot
var _active_platform: IntermissionPlatform
var _player_health_bar: ProgressBar
var _player_health_label: Label
var _gear_label: Label
var _boss_health_bar: ProgressBar
var _boss_label: Label
var _stage_label: Label
var _station_hint: Label
var _pause_menu: PauseMenu
var _stage_complete: bool = false


## Build the selected stage, connect the arena's event sources, and spawn its boss.
func _ready() -> void:
	# Build the stage from registry data before connecting events and spawning its boss.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	var stage := HelperFunctions.get_stage_resource()
	if stage == null:
		push_error("Arena: no stage resource is available for the current map.")
		return
	_build_arena_variant(stage)
	_build_hud(stage)
	# Player health and death signals update the HUD or send the run to the shop.
	player.health_changed.connect(_update_player_health)
	player.died.connect(_on_player_died)
	# Global gear changes refresh the arena HUD while the fight is active.
	Global.gears_changed.connect(_update_gears)
	_update_player_health(player.health, player.max_health)
	_update_gears(Global.gears, 0)
	_spawn_boss()


func _unhandled_input(event: InputEvent) -> void:
	# Consume pause and nearby-platform interactions before lower-priority handlers.
	if event.is_action_pressed(&"pause"):
		_mark_input_handled()
		_toggle_pause()
	elif event.is_action_pressed(&"interact") and is_instance_valid(_active_platform):
		_mark_input_handled()
		_interact_with_platform(_active_platform)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


## Instantiate the stage boss and connect its health and defeat signals to the arena.
func _spawn_boss() -> void:
	# BossRobot health and death signals feed the arena boss bar and clear flow.
	if _stage_complete:
		return
	var stage_resource := HelperFunctions.get_stage_resource()
	if stage_resource == null:
		push_error("Arena: no stage resource is available for the current boss.")
		return
	if stage_resource.boss_scene == null:
		push_error("Arena: current stage has no boss scene assigned.")
		return
	_boss = stage_resource.boss_scene.instantiate() as BossRobot
	if _boss == null:
		return
	_boss.configure_for_stage(stage_resource)
	_boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_boss)
	_boss.global_position = conveyor_mouth.global_position
	_boss.health_changed.connect(_update_boss_health)
	_boss.died.connect(_on_boss_died)
	_boss_label.text = "%s  ·  %s" % [stage_resource.display_name, stage_resource.ability]
	_update_boss_health(_boss.health, _boss.max_health)


## Award the clear bounty once, preserve health, and deploy the two post-boss choices.
func _on_boss_died(_robot: Node2D, _was_boss: bool, gear_reward: int) -> void:
	# Award the clear bounty once, preserve health, and deploy the intermission platforms.
	if _stage_complete:
		return
	_stage_complete = true
	HelperFunctions.mark_stage_cleared()
	Global.carried_player_health = player.health
	HelperFunctions.add_gears(gear_reward)
	if Global.stage_index == HelperFunctions.get_stage_count() - 1:
		Global.game_complete = true
	for hazard in get_tree().get_nodes_in_group("arena_hazards"):
		hazard.queue_free()
	var stage := HelperFunctions.get_stage_resource()
	var stage_name := stage.display_name if stage != null else "Robot"
	_boss_label.text = "STAGE CLEARED  ·  %s" % stage_name
	_boss_health_bar.value = 0.0
	_stage_label.text = "THE BOSS BROKE DOWN · %d GEARS LOOTED" % gear_reward
	_station_hint.text = "Use E at REPAIR / REFIT SHOP or MOVE TO NEXT STAGE"
	_station_hint.visible = true
	call_deferred("_deploy_intermission_platforms")


func _on_player_died() -> void:
	# The next human starts at Bolt; earned gears and purchased technology persist.
	Global.carried_player_health = -1.0
	Global.stage_index = 0
	Global.stage_cleared = false
	Global.game_complete = false
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/shop.tscn")


func _update_player_health(current: float, maximum: float) -> void:
	if not is_instance_valid(_player_health_bar):
		return
	_player_health_bar.max_value = maximum
	_player_health_bar.value = current
	_player_health_label.text = "FRAME  %d / %d" % [roundi(current), roundi(maximum)]


func _update_boss_health(current: float, maximum: float) -> void:
	if not is_instance_valid(_boss_health_bar):
		return
	_boss_health_bar.max_value = maximum
	_boss_health_bar.value = current


func _update_gears(total_gears: int, _change: int) -> void:
	if is_instance_valid(_gear_label):
		_gear_label.text = "GEARS  %d" % total_gears


## Offer exactly two post-boss choices: repair/refit, or move to the next boss.
func _deploy_intermission_platforms() -> void:
	var gate_id: StringName = &"advance"
	var gate_title := "NEXT ROBOT"
	if Global.stage_index == HelperFunctions.get_stage_count() - 1:
		gate_id = &"finale"
		gate_title = "EXIT / VICTORY"

	_create_intermission_platform(&"shop", "REPAIR / REFIT SHOP", Vector2(-270, 328), -430)
	_create_intermission_platform(gate_id, gate_title, Vector2(270, 328), 430)


## Create one sliding choice platform and forward its enter/exit signals to the arena.
func _create_intermission_platform(
	action_id: StringName,
	title: String,
	target_position: Vector2,
	start_x: float
) -> void:
	# Platform enter/exit signals below drive the shared interaction prompt.
	var platform := PLATFORM_SCENE.instantiate() as IntermissionPlatform
	if platform == null:
		return
	platform.setup(action_id, title)
	platform.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(platform)
	platform.position = Vector2(start_x, target_position.y)
	platform.player_entered.connect(_on_platform_entered)
	platform.player_exited.connect(_on_platform_exited)
	var tween := create_tween()
	var movement_tween := tween.tween_property(platform, "position", target_position, 0.55)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	movement_tween.set_ease(Tween.EASE_OUT)


func _on_platform_entered(platform: IntermissionPlatform) -> void:
	# IntermissionPlatform emits this after the player enters its interaction area.
	_active_platform = platform
	_station_hint.text = "E  ·  %s" % platform.display_name
	_station_hint.visible = true


func _on_platform_exited(platform: IntermissionPlatform) -> void:
	# Ignore exit events from platforms that are no longer the active target.
	if _active_platform == platform:
		_active_platform = null
		_station_hint.text = "Use E at REPAIR / REFIT SHOP or MOVE TO NEXT STAGE"


## Route the repair/refit choice or stage transition to its destination.
func _interact_with_platform(platform: IntermissionPlatform) -> void:
	# Route each stage service to its effect and each gate to the appropriate scene.
	match platform.interaction_id:
		&"shop":
			get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")
		&"advance":
			if HelperFunctions.advance_stage():
				get_tree().reload_current_scene()
		&"finale":
			Global.game_complete = true
			get_tree().change_scene_to_file("res://scenes/ui/victory.tscn")
## Apply the stage tint while keeping the boss arena clear of jumpable platforms.
func _build_arena_variant(stage: StageData) -> void:
	# Stage tint keeps arenas distinct; attack patterns now provide the movement challenge.
	var tint: Color = stage.arena_color
	background.color = tint
	floor_visual.color = tint.lightened(0.65)
	left_wall_visual.color = tint.lightened(0.8)
	right_wall_visual.color = tint.lightened(0.8)
	conveyor_visual.color = tint.lerp(Color(0.95, 0.38, 0.16), 0.55)


## Create the arena HUD and pause panel from runtime controls.
func _build_hud(stage: StageData) -> void:
	# Build the HUD and pause panel in code so the shared arena scene stays data-driven.
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)

	var status := VBoxContainer.new()
	status.position = Vector2(24, 18)
	status.size = Vector2(340, 90)
	status.add_theme_constant_override("separation", 4)
	frame.add_child(status)
	_player_health_label = Label.new()
	_player_health_label.text = "FRAME"
	_player_health_label.add_theme_font_size_override("font_size", 18)
	status.add_child(_player_health_label)
	_player_health_bar = _make_bar(Color(0.2, 0.82, 0.56), Vector2(330, 18))
	status.add_child(_player_health_bar)
	var controls := Label.new()
	controls.text = "A/D MOVE · SPACE JUMP · Q DASH\nM1 LIGHT · M2 HEAVY · ESC PAUSE"
	controls.add_theme_font_size_override("font_size", 11)
	status.add_child(controls)
	var ability_controls := Label.new()
	var unlocked_controls := PackedStringArray()
	if HelperFunctions.is_ability_unlocked(&"emp"):
		unlocked_controls.append("Z EMP")
	if HelperFunctions.is_ability_unlocked(&"repair"):
		unlocked_controls.append("X REPAIR")
	if HelperFunctions.is_ability_unlocked(&"overclock"):
		unlocked_controls.append("C OVERDRIVE")
	ability_controls.text = "  ·  ".join(unlocked_controls)
	ability_controls.visible = not unlocked_controls.is_empty()
	ability_controls.add_theme_font_size_override("font_size", 11)
	status.add_child(ability_controls)

	_gear_label = Label.new()
	_gear_label.position = Vector2(880, 18)
	_gear_label.size = Vector2(240, 32)
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gear_label.add_theme_font_size_override("font_size", 20)
	frame.add_child(_gear_label)

	_stage_label = Label.new()
	_stage_label.text = stage.title
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.position = Vector2(360, 16)
	_stage_label.size = Vector2(430, 26)
	_stage_label.add_theme_font_size_override("font_size", 17)
	frame.add_child(_stage_label)

	var boss_status := VBoxContainer.new()
	boss_status.position = Vector2(400, 45)
	boss_status.size = Vector2(350, 58)
	boss_status.add_theme_constant_override("separation", 4)
	frame.add_child(boss_status)
	_boss_label = Label.new()
	_boss_label.text = stage.display_name
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_status.add_child(_boss_label)
	_boss_health_bar = _make_bar(Color(0.9, 0.2, 0.22), Vector2(330, 18))
	boss_status.add_child(_boss_health_bar)

	_station_hint = Label.new()
	_station_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_station_hint.offset_top = -54
	_station_hint.offset_bottom = -26
	_station_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_station_hint.add_theme_font_size_override("font_size", 16)
	_station_hint.visible = false
	frame.add_child(_station_hint)

	# The shared pause menu stays active while the arena and player are paused.
	_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	if _pause_menu != null:
		frame.add_child(_pause_menu)


func _toggle_pause() -> void:
	# Keep the arena active to receive Escape while the child pause menu stays visible.
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	if _pause_menu != null:
		_pause_menu.set_menu_visible(should_pause)


func _make_bar(fill_color: Color, minimum_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = minimum_size
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _make_stylebox(fill_color))
	bar.add_theme_stylebox_override("background", _make_stylebox(Color(0.12, 0.14, 0.18)))
	return bar


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
