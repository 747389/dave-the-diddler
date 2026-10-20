class_name IntermissionPlatform
extends StaticBody2D

signal player_entered(platform: IntermissionPlatform)
signal player_exited(platform: IntermissionPlatform)

var interaction_id: StringName = &"shop"
var display_name: String = "Refit Station"


func _ready() -> void:
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	$Label.text = display_name
	set_meta("interaction_id", interaction_id)


func setup(action_id: StringName, title: String) -> void:
	interaction_id = action_id
	display_name = title


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_entered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_exited.emit(self)
