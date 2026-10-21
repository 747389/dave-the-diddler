class_name BossAttack
extends Area2D

var damage: float = 1.0
var travel_velocity: Vector2 = Vector2.ZERO
var grav: Vector2 = Vector2.ZERO
var lifetime: float = 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	# Area2D emits body_entered when the player overlaps this damaging shape.
	body_entered.connect(_on_body_entered)
	add_to_group("arena_hazards")


func configure_circle(
	radius: float,
	tint: Color,
	hit_damage: float,
	velocity: Vector2,
	duration: float,
	fall_gravity: Vector2 = Vector2.ZERO
) -> void:
	damage = hit_damage
	travel_velocity = velocity
	grav = fall_gravity
	lifetime = duration
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	add_child(collision)
	var visual := Polygon2D.new()
	visual.color = tint
	visual.polygon = _circle_points(radius, 12)
	add_child(visual)


## Construct one reusable visible collision wall or ripple.
func configure_rectangle(
	size: Vector2,
	tint: Color,
	hit_damage: float,
	velocity: Vector2,
	duration: float
) -> void:
	damage = hit_damage
	travel_velocity = velocity
	lifetime = duration
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	add_child(collision)
	var half_size := size * 0.5
	var visual := Polygon2D.new()
	visual.color = tint
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	add_child(visual)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	travel_velocity += grav * delta
	global_position += travel_velocity * delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in segments:
		var angle := TAU * float(point_index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
