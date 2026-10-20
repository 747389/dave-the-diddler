class_name ScrapProjectile
extends Area2D

var direction: Vector2 = Vector2.LEFT
var speed: float = 250.0
var damage: float = 12.0
var _lifetime: float = 5.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("arena_hazards")
	body_entered.connect(_on_body_entered)


func configure(fire_direction: Vector2, projectile_speed: float, hit_damage: float, tint: Color) -> void:
	direction = fire_direction.normalized()
	speed = projectile_speed
	damage = hit_damage
	$Visual.color = tint


func _process(delta: float) -> void:
	_lifetime -= delta
	global_position += direction * speed * delta
	if _lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	body.call("take_damage", damage)
	queue_free()
