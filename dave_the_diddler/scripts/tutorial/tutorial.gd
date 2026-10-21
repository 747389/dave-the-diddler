extends Node2D

const MOVE_TARGET_X: float = 450.0
const JUMP_TARGET_MIN_X: float = 540.0
const JUMP_TARGET_MAX_X: float = 720.0
const GAP_COMPLETION_X: float = 1450.0

@onready var player: Player = $Player
@onready var shoot_dummy: TrainingDummy = $ShootDummy
@onready var melee_dummy: TrainingDummy = $MeleeDummy
@onready var final_dummy: TrainingDummy = $FinalDummy
@onready var _objective_label: Label = $TutorialHUD/ObjectivePanel/MarginContainer/ObjectiveContent/ObjectiveText
@onready var _step_label: Label = $TutorialHUD/ObjectivePanel/MarginContainer/ObjectiveContent/StepText
@onready var _controls_label: Label = $TutorialHUD/ControlsText
@onready var _dummy_health_bar: ProgressBar = $TutorialHUD/DummyPanel/DummyContent/DummyHealthBar
@onready var _dummy_health_text: Label = $TutorialHUD/DummyPanel/DummyContent/DummyHealthText
@onready var _dummy_panel: PanelContainer = $TutorialHUD/DummyPanel
@onready var _completion_panel: PanelContainer = $TutorialHUD/CompletionPanel
@onready var _pause_menu: PauseMenu = $TutorialHUD/PauseMenu
@onready var _campaign_button: Button = $TutorialHUD/CompletionPanel/CompletionContent/CampaignButton
@onready var _title_button: Button = $TutorialHUD/CompletionPanel/CompletionContent/TitleButton

var _objective_index: int = 0
var _active_dummy: TrainingDummy
var _melee_light_used: bool = false
var _melee_heavy_used: bool = false
var _target_markers: Array[Node2D] = []


## Prepare the six-step lesson and connect its dummy and player event signals.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_objective_markers()
	# The completion scene buttons connect to the existing campaign and title actions.
	_campaign_button.pressed.connect(HelperFunctions.start_new_run)
	_title_button.pressed.connect(_return_to_title)
	# Each target reports its health, then passes itself to the defeat handler.
	for dummy in [shoot_dummy, melee_dummy, final_dummy]:
		dummy.deactivate()
		dummy.health_changed.connect(_update_dummy_health)
		dummy.died.connect(_on_dummy_died.bind(dummy))
	# Confirmed sword hits let the melee objective require both attack buttons.
	player.melee_attack_landed.connect(_on_melee_attack_landed)
	_show_objective(0)


## Advance movement, jump, and gap steps only after their world-space conditions are met.
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
				and player.global_position.y < 900.0
			):
				_show_objective(2)
		4:
			if player.global_position.x > GAP_COMPLETION_X:
				_show_objective(5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_toggle_pause()


## Draw a marker for each movement, aiming, melee, traversal, and final combat objective.
func _build_objective_markers() -> void:
	_target_markers.append(_make_target_marker(Vector2(MOVE_TARGET_X, 950), "MOVE HERE"))
	_target_markers.append(_make_target_marker(Vector2(650, 875), "JUMP HERE"))
	_target_markers.append(_make_target_marker(Vector2(900, 775), "SHOOT DUMMY"))
	_target_markers.append(_make_target_marker(Vector2(500, 950), "MELEE DUMMY"))
	_target_markers.append(_make_target_marker(Vector2(1100, 950), "JUMP + DASH"))
	_target_markers.append(_make_target_marker(Vector2(1610, 950), "FINAL TARGET"))


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


## Update instructions, target visibility, dummy health, and the completion card.
func _show_objective(index: int) -> void:
	_objective_index = index
	for marker_index in _target_markers.size():
		_target_markers[marker_index].visible = marker_index == index and index < 6
	var next_dummy: TrainingDummy
	match index:
		2:
			next_dummy = shoot_dummy
		3:
			next_dummy = melee_dummy
		5:
			next_dummy = final_dummy
	if is_instance_valid(_active_dummy) and _active_dummy != next_dummy:
		_active_dummy.deactivate()
	_active_dummy = next_dummy
	if index == 3:
		_melee_light_used = false
		_melee_heavy_used = false
	if is_instance_valid(_active_dummy):
		_active_dummy.activate()
		_dummy_panel.visible = true
	else:
		_dummy_panel.visible = false

	match index:
		0:
			_step_label.text = "TRAINING  //  01 OF 06"
			_objective_label.text = "Move right to the yellow marker using A/D or ←/→."
		1:
			_step_label.text = "TRAINING  //  02 OF 06"
			_objective_label.text = "Jump onto the raised platform with Space, W, or ↑."
		2:
			_step_label.text = "TRAINING  //  03 OF 06"
			_objective_label.text = "Point the gun at the dummy with your mouse. Click M1 until it breaks; ammo is unlimited."
			_controls_label.text = "AIM WITH MOUSE · M1 FIRE"
		3:
			_step_label.text = "TRAINING  //  04 OF 06"
			_objective_label.text = "Press Tab to equip the sword. Hit this dummy with both M1 light and M2 heavy attacks."
			_controls_label.text = "TAB SWORD · M1 LIGHT · M2 HEAVY"
		4:
			_step_label.text = "TRAINING  //  05 OF 06"
			_objective_label.text = "Jump and dash over the whole gap"
			_controls_label.text = "JUMP · SHIFT DASH"
		5:
			_step_label.text = "TRAINING  //  06 OF 06"
			_objective_label.text = "Defeat the final dummy using any weapon or attack."
			_controls_label.text = "ANY WEAPON · ANY ATTACK"
		6:
			_step_label.text = "TRAINING COMPLETE"
			_objective_label.text = "You are ready to enter the robot arena."
			_completion_panel.visible = true


func _update_dummy_health(current_health: float, maximum_health: float) -> void:
	_dummy_health_bar.max_value = maximum_health
	_dummy_health_bar.value = current_health
	var target_name := _active_dummy.display_name if is_instance_valid(_active_dummy) else "TRAINING DUMMY"
	_dummy_health_text.text = "%s  ·  %d / %d" % [
		target_name,
		roundi(current_health),
		roundi(maximum_health)
	]


func _on_dummy_died(dummy: TrainingDummy) -> void:
	# A defeated active target advances to the next lesson; the final target opens completion.
	if dummy != _active_dummy:
		return
	match _objective_index:
		2:
			_show_objective(_objective_index + 1)
		3:
			if not _melee_light_used or not _melee_heavy_used:
				_active_dummy.activate()
				_objective_label.text = "Use both M1 light and M2 heavy attacks. The dummy is restored so you can finish the lesson."
				return
			_show_objective(4)
		5:
			_show_objective(6)


func _on_melee_attack_landed(target: Node2D, is_heavy: bool) -> void:
	# Record only landed sword strikes against the active melee lesson target.
	if _objective_index != 3 or target != melee_dummy:
		return
	if is_heavy:
		_melee_heavy_used = true
	else:
		_melee_light_used = true


func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	if _pause_menu != null:
		_pause_menu.set_menu_visible(should_pause)


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
