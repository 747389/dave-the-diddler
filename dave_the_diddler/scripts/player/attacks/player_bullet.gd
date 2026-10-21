class_name PlayerBullet
extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.4

var _direction: Vector2 = Vector2.RIGHT
var _damage: float = 14.0
var _time_left: float = 0.0


## Connect the impact signal to the handler that applies damage and removes the shot.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Launch the bullet with the weapon's direction and damage, then remove it on impact or expiry.
func launch(direction: Vector2, damage: float) -> void:
	_direction = direction.normalized()
	_damage = damage
	_time_left = lifetime
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	global_position += _direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", _damage)
		queue_free()
