extends Control


## Present the completed run and connect replay to the shared run-reset helper.
func _ready() -> void:
	# Present the completed run and connect the replay button to the shared restart helper.
	var background := ColorRect.new()
	background.color = Color(0.055, 0.075, 0.11, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.offset_left = -260
	content.offset_right = 260
	content.offset_top = -110
	content.offset_bottom = 110
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var title := Label.new()
	title.text = "HUMANITY HOLDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	content.add_child(title)

	var result := Label.new()
	result.text = "All five robots defeated. The machine arena is silent."
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(result)

	var restart_button := Button.new()
	restart_button.text = "Run it again"
	restart_button.pressed.connect(HelperFunctions.restart_run)
	content.add_child(restart_button)
