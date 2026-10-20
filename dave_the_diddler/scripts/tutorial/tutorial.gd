extends Node2D

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const MOVE_TARGET_X: float = -270.0
const JUMP_TARGET_MIN_X: float = -95.0
const JUMP_TARGET_MAX_X: float = 135.0

@onready var player: Player = $Player
@onready var training_dummy: TrainingDummy = $TrainingDummy

var _objective_index: int = 0
var _objective_label: Label
var _step_label: Label
var _dummy_health_bar: ProgressBar
var _dummy_health_text: Label
var _dummy_panel: PanelContainer
var _completion_panel: PanelContainer
var _pause_menu: PauseMenu
var _target_markers: Array[Node2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_objective_markers()
	_build_hud()
	# The tutorial observes the dummy's health and defeat signals to finish the final task.
	training_dummy.health_changed.connect(_update_dummy_health)
	training_dummy.died.connect(_on_dummy_died)
	_update_dummy_health(training_dummy.health, training_dummy.max_health)
	_show_objective(0)


## Advance the move and jump steps only after the player reaches each world target.
func _process(_delta: float) -> void:
	if get_tree().paused:
		return

	match _objective_index:
		0:
			if player.global_position.x >= MOVE_TARGET_X:
				_show_objective(1)
		1:
			if (
				player.is_on_floor()
				and player.global_position.x >= JUMP_TARGET_MIN_X
				and player.global_position.x <= JUMP_TARGET_MAX_X
				and player.global_position.y < 420.0
			):
				_show_objective(2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_toggle_pause()


## Draw world-space markers above the move target, ledge, and training dummy.
func _build_objective_markers() -> void:
	_target_markers.append(_make_target_marker(Vector2(MOVE_TARGET_X, 450), "MOVE HERE"))
	_target_markers.append(_make_target_marker(Vector2(20, 350), "JUMP HERE"))
	_target_markers.append(_make_target_marker(Vector2(465, 365), "ATTACK DUMMY"))


## Create a world-space ring and label that identify one tutorial objective.
func _make_target_marker(marker_position: Vector2, marker_text: String) -> Node2D:
	var marker := Node2D.new()
	marker.position = marker_position
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.68, 0.18, 0.95)
	var points := PackedVector2Array()
	for point_index in 33:
		var angle := TAU * float(point_index) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * 30.0)
	ring.points = points
	marker.add_child(ring)

	var label := Label.new()
	label.text = marker_text
	label.position = Vector2(-70.0, -62.0)
	label.size = Vector2(140.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	marker.add_child(label)
	add_child(marker)
	return marker


## Create the objective HUD, dummy health display, completion card, and shared pause menu.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TutorialHUD"
	add_child(layer)

	var objective_panel := PanelContainer.new()
	objective_panel.position = Vector2(24.0, 20.0)
	objective_panel.custom_minimum_size = Vector2(430.0, 0.0)
	layer.add_child(objective_panel)
	var objective_content := VBoxContainer.new()
	objective_content.add_theme_constant_override("separation", 5)
	objective_panel.add_child(objective_content)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 14)
	objective_content.add_child(_step_label)
	_objective_label = Label.new()
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 18)
	objective_content.add_child(_objective_label)
	var controls := Label.new()
	controls.text = "MOVE A/D · JUMP Space · M1 LIGHT · M2 HEAVY · PAUSE Esc"
	controls.position = Vector2(24.0, 112.0)
	controls.add_theme_font_size_override("font_size", 13)
	layer.add_child(controls)

	_dummy_panel = PanelContainer.new()
	_dummy_panel.position = Vector2(890.0, 22.0)
	_dummy_panel.custom_minimum_size = Vector2(350.0, 0.0)
	layer.add_child(_dummy_panel)
	var dummy_content := VBoxContainer.new()
	dummy_content.add_theme_constant_override("separation", 5)
	_dummy_panel.add_child(dummy_content)
	_dummy_health_text = Label.new()
	_dummy_health_text.text = "TRAINING DUMMY"
	_dummy_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dummy_content.add_child(_dummy_health_text)
	_dummy_health_bar = ProgressBar.new()
	_dummy_health_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_dummy_health_bar.show_percentage = false
	dummy_content.add_child(_dummy_health_bar)
	_dummy_panel.visible = false

	_completion_panel = PanelContainer.new()
	_completion_panel.custom_minimum_size = Vector2(430.0, 0.0)
	_completion_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_completion_panel.visible = false
	layer.add_child(_completion_panel)
	var completion_content := VBoxContainer.new()
	completion_content.add_theme_constant_override("separation", 12)
	_completion_panel.add_child(completion_content)
	var completion_title := Label.new()
	completion_title.text = "TRAINING COMPLETE"
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.add_theme_font_size_override("font_size", 26)
	completion_content.add_child(completion_title)
	var completion_text := Label.new()
	completion_text.text = "You can move, jump, and break a robot. The campaign is ready."
	completion_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_content.add_child(completion_text)
	var campaign_button := Button.new()
	campaign_button.text = "START CAMPAIGN"
	# The completion card can immediately reset the run and enter the campaign.
	campaign_button.pressed.connect(HelperFunctions.start_new_run)
	completion_content.add_child(campaign_button)
	var title_button := Button.new()
	title_button.text = "RETURN TO TITLE"
	title_button.pressed.connect(_return_to_title)
	completion_content.add_child(title_button)

	_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	if _pause_menu != null:
		layer.add_child(_pause_menu)


## Update instructions, target visibility, dummy health, and the completion card.
func _show_objective(index: int) -> void:
	_objective_index = index
	for marker_index in _target_markers.size():
		_target_markers[marker_index].visible = marker_index == index and index < 3
	_dummy_panel.visible = index == 2

	match index:
		0:
			_step_label.text = "TRAINING  //  01 OF 03"
			_objective_label.text = "Move right to the yellow marker using A/D or ←/→."
		1:
			_step_label.text = "TRAINING  //  02 OF 03"
			_objective_label.text = "Jump onto the raised platform with Space, W, or ↑."
		2:
			_step_label.text = "TRAINING  //  03 OF 03"
			_objective_label.text = "Land 3 M1 light hits, then use M2 for an empowered heavy attack."
		3:
			_step_label.text = "TRAINING COMPLETE"
			_objective_label.text = "You are ready to enter the robot arena."
			_completion_panel.visible = true


func _update_dummy_health(current_health: float, maximum_health: float) -> void:
	_dummy_health_bar.max_value = maximum_health
	_dummy_health_bar.value = current_health
	_dummy_health_text.text = "TRAINING DUMMY  ·  %d / %d" % [
		roundi(current_health),
		roundi(maximum_health)
	]


func _on_dummy_died() -> void:
	# The dummy emits died after its health_changed signal reaches zero.
	_show_objective(3)


func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	if _pause_menu != null:
		_pause_menu.set_menu_visible(should_pause)


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
