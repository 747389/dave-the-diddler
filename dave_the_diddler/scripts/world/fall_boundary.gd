extends Area2D

@export var target_path: NodePath = ^"../Player"
@export var spawn_position: Vector2 = Vector2.ZERO

var _target: Node2D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	# The sensor reports bodies crossing the lower map edge; this handler restores the player.
	body_entered.connect(_on_body_entered)


## Watch the boundary height too, so a dash with the player's collision layer disabled still resets.
func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target) and _target.global_position.y >= global_position.y:
		_reset_target()


## Return the configured player to its scene spawn and clear movement state after a fall.
func _on_body_entered(body: Node2D) -> void:
	if body != _target:
		return
	_reset_target()


func _reset_target() -> void:
	_target.global_position = spawn_position
	if _target is CharacterBody2D:
		_target.velocity = Vector2.ZERO
	if _target.has_method("refresh_dash"):
		_target.call("refresh_dash")
