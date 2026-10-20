class_name PauseMenu
extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_pause_menu()
	visible = false


## Keep the menu interactive while the game tree is paused.
func set_menu_visible(should_show: bool) -> void:
	visible = should_show


## Build one reusable pause overlay for the campaign and training scenes.
func _build_pause_menu() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	var resume_button := _make_button("RESUME")
	# Resume unpauses the tree and hides this overlay.
	resume_button.pressed.connect(_resume)
	content.add_child(resume_button)

	var title_button := _make_button("RETURN TO TITLE")
	# Returning to title clears the pause state before changing scenes.
	title_button.pressed.connect(_return_to_title)
	content.add_child(title_button)

	var quit_button := _make_button("QUIT GAME")
	# Quit exits the game from either the arena or the tutorial.
	quit_button.pressed.connect(_quit_game)
	content.add_child(quit_button)


func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 17)
	return button


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _quit_game() -> void:
	get_tree().quit()
