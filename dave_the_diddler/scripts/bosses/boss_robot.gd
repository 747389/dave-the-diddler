class_name BossRobot
extends CharacterBody2D

## Arena connects this to the boss health bar after the selected boss is spawned.
signal health_changed(current_health: float, max_health: float)
## Arena listens for this to award gears and open the two post-boss choices.
signal died(robot: Node2D, was_boss: bool, gear_reward: int)

@export var max_health: float = 50.0
@export var move_speed: float = 85.0
@export var contact_damage: float = 10.0
@export var gear_reward: int = 8
@export var attack_damage: float = 20.0
@export var attack_interval: float = 2.4
@export_range(0.1, 1.0, 0.05) var warning_duration: float = 0.35
@export var warning_radius: float = 48.0
@export var can_jump: bool = false
@export var jump_velocity: float = -330.0
@export var jump_interval: float = 4.0
@export var can_flash_step: bool = false
@export var flash_step_distance: float = 180.0

var health: float = 0.0
var stage_id: int = 0
var boss_name: String = "Robot"
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var _contact_cooldown: float = 0.0
var _attack_cooldown_left: float = 1.8
var _attack_windup_left: float = 0.0
var _jump_cooldown_left: float = 2.0
var _warning_visual: Node2D
var _is_dead: bool = false
var _base_color: Color = Color(0.82, 0.52, 0.24)


## Apply stage resource stats to the boss scene selected for this fight.
func configure_for_stage(stage: StageData) -> void:
	if stage == null:
		return
	stage_id = stage.order
	boss_name = stage.display_name
	max_health = stage.health
	move_speed = stage.speed
	contact_damage = stage.contact_damage
	gear_reward = stage.gear_reward
	attack_damage = stage.attack_damage
	attack_interval = stage.attack_interval
	warning_duration = stage.warning_duration
	can_jump = stage.can_jump
	can_flash_step = stage.can_flash_step
	flash_step_distance = stage.flash_step_distance
	health = max_health
	_base_color = _stage_color(stage_id)
	$Visual.color = _base_color
	$Visual.polygon = _stage_polygon(stage_id)
	scale = Vector2.ONE * (1.0 + float(stage_id) * 0.08)
	set_meta("boss_name", boss_name)
	set_meta("stage_index", stage_id)


func _ready() -> void:
	add_to_group("robots")
	if health <= 0.0:
		health = max_health
	$Visual.color = _base_color
	health_changed.emit(health, max_health)


## Coordinate warnings, boss-specific attack hooks, movement, gravity, and body contact.
func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_jump_cooldown_left = maxf(_jump_cooldown_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var direction := 0.0
	if player != null:
		direction = signf(player.global_position.x - global_position.x)
	if _attack_windup_left > 0.0:
		_attack_windup_left = maxf(_attack_windup_left - delta, 0.0)
		velocity.x = 0.0
		if _attack_windup_left <= 0.0:
			_clear_attack_warning()
			_execute_major_attack(player, direction)
	elif _attack_cooldown_left <= 0.0:
		_try_start_attack(player, direction)
	if _attack_windup_left <= 0.0:
		_try_jump(player)
		_update_custom_motion(delta, player, direction)
	if not is_on_floor():
		velocity.y += _gravity * delta
	move_and_slide()
	_check_player_contact()


## Award gears only for applied damage and emit the one-time defeat signal at zero health.
func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	var applied_damage := minf(amount, health)
	health = maxf(health - applied_damage, 0.0)
	HelperFunctions.show_damage_number(self, applied_damage, Color(1.0, 0.86, 0.42))
	HelperFunctions.award_damage_gears(applied_damage)
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_dead = true
		died.emit(self, true, gear_reward)
		queue_free()


## Reserve the attack beat and show an adjustable red tell around this boss.
func begin_major_attack() -> bool:
	if _attack_windup_left > 0.0 or _attack_cooldown_left > 0.0:
		return false
	_attack_windup_left = warning_duration
	_attack_cooldown_left = attack_interval
	_show_attack_warning()
	return true


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	pass


func _execute_major_attack(_player: Node2D, _direction: float) -> void:
	pass


func _update_custom_motion(_delta: float, _player: Node2D, direction: float) -> void:
	velocity.x = direction * move_speed


func spawn_circle_hazard(
	pos: Vector2,
	radius: float,
	tint: Color,
	damage: float,
	travel_velocity: Vector2 = Vector2.ZERO,
	lifetime: float = 3.0,
	fall_gravity: Vector2 = Vector2.ZERO
) -> void:
	var hazard := BossAttack.new()
	hazard.configure_circle(radius, tint, damage, travel_velocity, lifetime, fall_gravity)
	_add_hazard(hazard, pos)


func spawn_rectangle_hazard(
	pos: Vector2,
	size: Vector2,
	tint: Color,
	damage: float,
	travel_velocity: Vector2,
	lifetime: float = 3.0
) -> void:
	var hazard := BossAttack.new()
	hazard.configure_rectangle(size, tint, damage, travel_velocity, lifetime)
	_add_hazard(hazard, pos)


func _add_hazard(hazard: BossAttack, pos: Vector2) -> void:
	var arena := get_tree().current_scene
	if arena == null:
		return
	hazard.global_position = pos
	arena.call_deferred("add_child", hazard)


func _try_jump(player: Node2D) -> void:
	if not can_jump or player == null or _jump_cooldown_left > 0.0 or not is_on_floor():
		return
	velocity.y = jump_velocity
	_jump_cooldown_left = jump_interval


func flash_step_toward(player: Node2D) -> void:
	if not can_flash_step or player == null:
		return
	var away_direction := signf(global_position.x - player.global_position.x)
	if is_zero_approx(away_direction):
		away_direction = 1.0
	global_position.x = clampf(
		player.global_position.x + away_direction * flash_step_distance,
		-470.0,
		470.0
	)


## Surround the boss with a light red polygon for its configurable warning beat.
func _show_attack_warning() -> void:
	var warning := Node2D.new()
	warning.name = "AttackWarning"
	warning.z_index = 4
	add_child(warning)
	_warning_visual = warning
	var circle := PackedVector2Array()
	for point_index in 18:
		var angle := TAU * float(point_index) / 18.0
		circle.append(Vector2(cos(angle), sin(angle)) * warning_radius)
	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.22, 0.25, 0.25)
	fill.polygon = circle
	warning.add_child(fill)
	circle.append(circle[0])
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.34, 0.38, 0.95)
	outline.points = circle
	warning.add_child(outline)
	var tween := warning.create_tween()
	tween.tween_property(warning, "modulate:a", 0.0, warning_duration)
	tween.tween_callback(warning.queue_free)


func _clear_attack_warning() -> void:
	if is_instance_valid(_warning_visual):
		_warning_visual.queue_free()
	_warning_visual = null


func _check_player_contact() -> void:
	if _contact_cooldown > 0.0:
		return
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider() as Node2D
		if collider == null or not collider.is_in_group("player"):
			continue
		# Head contact is safe so the Hopper's low ripples have a clear counterplay.
		if collider.global_position.y < global_position.y - 20.0:
			continue
		collider.call("take_damage", contact_damage)
		_contact_cooldown = 0.9
		return


func _stage_color(index: int) -> Color:
	var colors := [
		Color(0.92, 0.38, 0.2), Color(0.9, 0.68, 0.18), Color(0.22, 0.82, 0.72),
		Color(0.42, 0.62, 0.92), Color(0.86, 0.16, 0.32)
	]
	return colors[clampi(index, 0, colors.size() - 1)]


## Return a compact silhouette for the stage selected by its resource order.
func _stage_polygon(index: int) -> PackedVector2Array:
	match index:
		1:
			return PackedVector2Array([Vector2(-18, -30), Vector2(18, -30), Vector2(27, 12), Vector2(12, 25), Vector2(-12, 25), Vector2(-27, 12)])
		2:
			return PackedVector2Array([Vector2(-30, -17), Vector2(-22, -30), Vector2(22, -30), Vector2(30, -17), Vector2(30, 17), Vector2(22, 30), Vector2(-22, 30), Vector2(-30, 17)])
		3:
			return PackedVector2Array([Vector2(-26, -26), Vector2(26, -26), Vector2(34, -10), Vector2(26, 0), Vector2(34, 10), Vector2(26, 26), Vector2(-26, 26), Vector2(-34, 10), Vector2(-26, 0), Vector2(-34, -10)])
		4:
			return PackedVector2Array([Vector2(-28, -28), Vector2(-9, -20), Vector2(0, -35), Vector2(9, -20), Vector2(28, -28), Vector2(20, -4), Vector2(35, 0), Vector2(20, 8), Vector2(28, 28), Vector2(0, 20), Vector2(-28, 28), Vector2(-20, 8), Vector2(-35, 0), Vector2(-20, -4)])
		_:
			return PackedVector2Array([Vector2(-22, -24), Vector2(22, -24), Vector2(30, 0), Vector2(20, 24), Vector2(-20, 24), Vector2(-30, 0)])
