extends Control

@onready var restart_button: Button = $Center/Content/RestartButton


## Connect replay to the shared run reset helper.
func _ready() -> void:
	# The scene-authored replay button resets run progress and starts the campaign.
	restart_button.pressed.connect(HelperFunctions.restart_run)
