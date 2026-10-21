extends Control

@onready var start_button: Button = $Center/Content/StartButton
@onready var tutorial_button: Button = $Center/Content/TutorialButton
@onready var quit_button: Button = $Center/Content/QuitButton


func _ready() -> void:
	# Scene-authored menu buttons connect to the campaign, tutorial, and quit actions.
	start_button.pressed.connect(HelperFunctions.start_new_run)
	tutorial_button.pressed.connect(HelperFunctions.start_tutorial)
	quit_button.pressed.connect(_quit_game)


func _quit_game() -> void:
	get_tree().quit()
