class_name PauseMenu
extends Control

@onready var resume_button: Button = $Center/Panel/Content/ResumeButton
@onready var title_button: Button = $Center/Panel/Content/TitleButton
@onready var quit_button: Button = $Center/Panel/Content/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Scene-authored buttons route to the pause, title, and quit handlers.
	resume_button.pressed.connect(_resume)
	title_button.pressed.connect(_return_to_title)
	quit_button.pressed.connect(_quit_game)


## Keep the menu interactive while the game tree is paused.
func set_menu_visible(should_show: bool) -> void:
	visible = should_show


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _quit_game() -> void:
	get_tree().quit()
