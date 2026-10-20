extends Node2D

const ROBOT_SCENE: PackedScene = preload("res://scenes/robot.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://scenes/intermission_platform.tscn")

@onready var player: Player = $Player
@onready var conveyor_mouth: Marker2D = $Conveyor/Mouth
@onready var background: Polygon2D = $Background
@onready var floor_visual: Polygon2D = $Floor/Visual
@onready var left_wall_visual: Polygon2D = $LeftWall/Visual
@onready var right_wall_visual: Polygon2D = $RightWall/Visual
@onready var conveyor_visual: Polygon2D = $Conveyor/Belt

var _boss: Robot
var _active_platform: IntermissionPlatform
var _player_health_bar: ProgressBar
var _player_health_label: Label
var _gear_label: Label
var _boss_health_bar: ProgressBar
var _boss_label: Label
var _stage_label: Label
var _station_hint: Label
var _pause_panel: PanelContainer
var _stage_complete: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	var stage := GameState.get_stage_definition()
	_build_arena_variant(stage)
	_build_hud(stage)
	player.health_changed.connect(_update_player_health)
	player.died.connect(_on_player_died)
	GameState.gears_changed.connect(_update_gears)
	_update_player_health(player.health, player.max_health)
	_update_gears(GameState.gears, 0)
	_spawn_boss()


func _unhandled_input(event: InputEvent) -> void:
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


func _spawn_boss() -> void:
	if _stage_complete:
		return
	var stage := GameState.get_stage_definition()
	_boss = ROBOT_SCENE.instantiate() as Robot
	if _boss == null:
		return
	_boss.configure_for_stage(GameState.stage_index)
	_boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_boss)
	_boss.global_position = conveyor_mouth.global_position
	_boss.health_changed.connect(_update_boss_health)
	_boss.died.connect(_on_boss_died)
	_boss_label.text = "%s  ·  %s" % [str(stage.get("name", "Robot")), str(stage.get("ability", ""))]
	_update_boss_health(_boss.health, _boss.max_health)


func _on_boss_died(robot: Node2D, _was_boss: bool, gear_reward: int) -> void:
	if _stage_complete:
		return
	_stage_complete = true
	GameState.mark_stage_cleared()
	GameState.carried_player_health = player.health
	GameState.add_gears(gear_reward)
	if GameState.stage_index == GameState.STAGE_DEFINITIONS.size() - 1:
		GameState.game_complete = true
	for hazard in get_tree().get_nodes_in_group("arena_hazards"):
		hazard.queue_free()
	_boss_label.text = "STAGE CLEARED  ·  %s" % str(GameState.get_stage_definition().get("name", "Robot"))
	_boss_health_bar.value = 0.0
	_stage_label.text = "THE BOSS BROKE DOWN · %d GEARS LOOTED" % gear_reward
	_station_hint.text = "Platforms deploying — use E at an interaction platform"
	_station_hint.visible = true
	call_deferred("_deploy_intermission_platforms")


func _on_player_died() -> void:
	GameState.carried_player_health = -1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://scenes/shop.tscn")


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


func _deploy_intermission_platforms() -> void:
	var stage := GameState.get_stage_definition()
	var service_id: StringName = stage.get("service_id", &"repair")
	var service_title := str(stage.get("service_title", "Service Platform"))
	var gate_id: StringName = &"advance"
	var gate_title := "NEXT ROBOT"
	if GameState.stage_index == GameState.STAGE_DEFINITIONS.size() - 1:
		gate_id = &"finale"
		gate_title = "EXIT / VICTORY"

	_create_intermission_platform(&"shop", "REFIT SHOP", Vector2(-270, 328), -430)
	_create_intermission_platform(service_id, service_title, Vector2(0, 322), 430)
	_create_intermission_platform(gate_id, gate_title, Vector2(270, 328), 430)


func _create_intermission_platform(
	action_id: StringName,
	title: String,
	target_position: Vector2,
	start_x: float
) -> void:
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
	_active_platform = platform
	_station_hint.text = "E  ·  %s" % platform.display_name
	_station_hint.visible = true


func _on_platform_exited(platform: IntermissionPlatform) -> void:
	if _active_platform == platform:
		_active_platform = null
		_station_hint.text = "Platforms deployed — use E at an interaction platform"


func _interact_with_platform(platform: IntermissionPlatform) -> void:
	match platform.interaction_id:
		&"shop":
			get_tree().change_scene_to_file("res://scenes/shop.tscn")
		&"advance":
			if GameState.advance_stage():
				get_tree().reload_current_scene()
		&"finale":
			GameState.game_complete = true
			get_tree().change_scene_to_file("res://scenes/victory.tscn")
		&"repair":
			player.restore_health()
			_mark_station_used(platform, "REPAIRED")
		&"salvage":
			GameState.add_gears(30)
			_mark_station_used(platform, "+30 GEARS")
		&"dash_charge":
			GameState.bonus_air_dashes += 1
			_mark_station_used(platform, "AIR DASH CHARGED")
		&"shield":
			player.grant_temporary_shield(8.0)
			_mark_station_used(platform, "SHIELD CHARGED")


func _mark_station_used(platform: IntermissionPlatform, result_text: String) -> void:
	platform.display_name = result_text
	var station_label := platform.get_node("Label") as Label
	if station_label != null:
		station_label.text = result_text
	platform.interaction_id = &"used"
	var interaction_area := platform.get_node("InteractionArea") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
	_active_platform = null
	_station_hint.text = result_text


func _build_arena_variant(stage: Dictionary) -> void:
	var tint: Color = stage.get("arena_color", Color(0.055, 0.075, 0.11))
	background.color = tint
	floor_visual.color = tint.lightened(0.65)
	left_wall_visual.color = tint.lightened(0.8)
	right_wall_visual.color = tint.lightened(0.8)
	conveyor_visual.color = tint.lerp(Color(0.95, 0.38, 0.16), 0.55)
	match GameState.stage_index:
		1:
			_add_arena_platform(Vector2(-260, 330), Vector2(200, 18), Color(0.85, 0.47, 0.22))
			_add_arena_platform(Vector2(30, 315), Vector2(170, 18), Color(0.85, 0.47, 0.22))
			_add_arena_platform(Vector2(300, 330), Vector2(190, 18), Color(0.85, 0.47, 0.22))
		2:
			_add_arena_platform(Vector2(-320, 335), Vector2(140, 18), Color(0.2, 0.79, 0.72))
			_add_arena_platform(Vector2(-120, 315), Vector2(140, 18), Color(0.2, 0.79, 0.72))
			_add_arena_platform(Vector2(100, 335), Vector2(140, 18), Color(0.2, 0.79, 0.72))
			_add_arena_platform(Vector2(310, 315), Vector2(140, 18), Color(0.2, 0.79, 0.72))
		3:
			_add_arena_platform(Vector2(-300, 330), Vector2(180, 18), Color(0.46, 0.62, 0.95))
			_add_arena_platform(Vector2(0, 310), Vector2(220, 18), Color(0.46, 0.62, 0.95))
			_add_arena_platform(Vector2(300, 330), Vector2(180, 18), Color(0.46, 0.62, 0.95))
		4:
			_add_arena_platform(Vector2(-330, 330), Vector2(160, 18), Color(0.92, 0.2, 0.32))
			_add_arena_platform(Vector2(-140, 310), Vector2(140, 18), Color(0.92, 0.2, 0.32))
			_add_arena_platform(Vector2(120, 310), Vector2(140, 18), Color(0.92, 0.2, 0.32))
			_add_arena_platform(Vector2(330, 330), Vector2(160, 18), Color(0.92, 0.2, 0.32))


func _add_arena_platform(platform_position: Vector2, platform_size: Vector2, tint: Color) -> void:
	var body := StaticBody2D.new()
	body.position = platform_position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = platform_size
	shape.shape = rectangle
	body.add_child(shape)
	var visual := Polygon2D.new()
	visual.color = tint
	var half_size := platform_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	body.add_child(visual)
	add_child(body)


func _build_hud(stage: Dictionary) -> void:
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
	controls.text = "A/D MOVE  ·  SPACE JUMP  ·  F ATTACK  ·  Q DASH  ·  ESC PAUSE"
	controls.add_theme_font_size_override("font_size", 11)
	status.add_child(controls)
	var ability_controls := Label.new()
	ability_controls.text = "Z/X/C ABILITIES  ·  E INTERACT"
	ability_controls.add_theme_font_size_override("font_size", 11)
	status.add_child(ability_controls)

	_gear_label = Label.new()
	_gear_label.position = Vector2(880, 18)
	_gear_label.size = Vector2(240, 32)
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gear_label.add_theme_font_size_override("font_size", 20)
	frame.add_child(_gear_label)

	_stage_label = Label.new()
	_stage_label.text = str(stage.get("title", "STAGE"))
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
	_boss_label.text = str(stage.get("name", "Robot"))
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

	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -170
	_pause_panel.offset_right = 170
	_pause_panel.offset_top = -130
	_pause_panel.offset_bottom = 130
	_pause_panel.visible = false
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	frame.add_child(_pause_panel)
	var pause_content := VBoxContainer.new()
	pause_content.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(pause_content)
	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_content.add_child(pause_title)
	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_toggle_pause)
	pause_content.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "Restart run  (Ctrl + R)"
	restart_button.pressed.connect(GameState.restart_run)
	pause_content.add_child(restart_button)


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_panel.visible = get_tree().paused


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
