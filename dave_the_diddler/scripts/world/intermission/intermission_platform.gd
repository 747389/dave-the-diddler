class_name IntermissionPlatform
extends StaticBody2D

## Arena listens for this to display the platform's action prompt.
signal player_entered(platform: IntermissionPlatform)
## Arena listens for this to clear the prompt when the player walks away.
signal player_exited(platform: IntermissionPlatform)

var interaction_id: StringName = &"shop"
var display_name: String = "Refit Station"


func _ready() -> void:
	# Forward physics-area events through typed platform signals consumed by Arena.
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	$Label.text = display_name
	set_meta("interaction_id", interaction_id)


func setup(action_id: StringName, title: String) -> void:
	interaction_id = action_id
	display_name = title


func _on_body_entered(body: Node2D) -> void:
	# Only player bodies can activate an intermission platform.
	if body.is_in_group("player"):
		player_entered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	# Keep enter and exit filtering symmetric so other bodies cannot clear the prompt.
	if body.is_in_group("player"):
		player_exited.emit(self)
