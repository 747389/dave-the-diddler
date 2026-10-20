extends Control


func _ready() -> void:
	_build_title_screen()


## Build the title, short control reminder, and the three ways to proceed.
func _build_title_screen() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.085, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var accent := ColorRect.new()
	accent.color = Color(0.95, 0.38, 0.16, 1.0)
	accent.position = Vector2(0.0, 0.0)
	accent.size = Vector2(12.0, 720.0)
	add_child(accent)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(440.0, 0.0)
	content.add_theme_constant_override("separation", 16)
	center.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "A HUMANITY HOLDS THE LINE GAME"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 15)
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "MAN  VS  MACHINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Five robots. One scrap-built fighter."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var controls := Label.new()
	controls.text = "MOVE  A/D or ←/→     JUMP  Space     ATTACK  F\nDASH  Q     PAUSE  Esc"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	content.add_child(controls)

	var start_button := _make_button("START CAMPAIGN")
	# Campaign start resets run progress; training starts its own baseline session.
	start_button.pressed.connect(HelperFunctions.start_new_run)
	content.add_child(start_button)

	var tutorial_button := _make_button("TRAINING")
	tutorial_button.pressed.connect(HelperFunctions.start_tutorial)
	content.add_child(tutorial_button)

	var quit_button := _make_button("QUIT")
	# Quit remains available from the title screen without entering a scene.
	quit_button.pressed.connect(_quit_game)
	content.add_child(quit_button)


func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _quit_game() -> void:
	get_tree().quit()
