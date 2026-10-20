class_name Robot
extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/bosses/attacks/scrap_projectile.tscn")

## Arena connects this to its boss health bar after the current robot is spawned.
signal health_changed(current_health: float, max_health: float)
## Arena listens for this to award the clear bounty and deploy the next-step platforms.
signal died(robot: Node2D, was_boss: bool, gear_reward: int)

@export var max_health: float = 50.0
@export var move_speed: float = 85.0
@export var contact_damage: float = 10.0
@export var gear_reward: int = 8
@export var is_boss: bool = false

var health: float = 0.0
var stage_id: int = 0
var boss_name: String = "Scrap Robot"
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var _contact_cooldown: float = 0.0
var _special_timer: float = 2.6
var _jump_timer: float = 4.5
var _dash_time_left: float = 0.0
var _dash_direction: float = 1.0
var _was_airborne: bool = false
var _shield_cycle: float = 0.0
var _shielded: bool = false
var _slam_windup_left: float = 0.0
var _is_dead: bool = false
var _base_color: Color = Color(0.82, 0.52, 0.24)


## Apply stage resource stats and the matching boss silhouette to this robot.
func configure_for_stage(index: int) -> void:
	# Apply resource-driven boss stats and stage-specific polygon presentation.
	var definition := HelperFunctions.get_stage_definition(index)
	if definition.is_empty():
		return
	stage_id = index
	boss_name = str(definition.get("name", boss_name))
	max_health = float(definition.get("health", max_health))
	move_speed = float(definition.get("speed", move_speed))
	contact_damage = float(definition.get("contact_damage", contact_damage))
	gear_reward = int(definition.get("gear_reward", gear_reward))
	is_boss = true
	health = max_health
	_base_color = _stage_color(index)
	$Visual.color = _base_color
	$Visual.polygon = _stage_polygon(index)
	scale = Vector2.ONE * (1.0 + float(index) * 0.08)
	set_meta("boss_name", boss_name)
	set_meta("stage_index", index)


func _ready() -> void:
	add_to_group("robots")
	if health <= 0.0:
		health = max_health
	$Visual.color = _base_color
	health_changed.emit(health, max_health)


## Run the active boss pattern, gravity, collision response, and landing effects.
func _physics_process(delta: float) -> void:
	# Track the player, run the current boss pattern, then resolve movement and contact.
	if _is_dead:
		return
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var direction := 0.0
	if player != null:
		direction = signf(player.global_position.x - global_position.x)
	_run_stage_ability(delta, player, direction)
	if not is_on_floor():
		velocity.y += _gravity * delta
	_was_airborne = not is_on_floor()
	move_and_slide()
	if stage_id == 1 and _was_airborne and is_on_floor():
		_landing_shockwave(player)
	_check_player_collision()


func take_damage(amount: float) -> void:
	# Shielding reduces applied damage before both health loss and gear rewards are computed.
	if _is_dead or amount <= 0.0:
		return
	var applied_damage := amount * (0.35 if _shielded else 1.0)
	applied_damage = minf(applied_damage, health)
	health = maxf(health - applied_damage, 0.0)
	HelperFunctions.award_damage_gears(applied_damage)
	health_changed.emit(health, max_health)
	if is_zero_approx(health):
		_is_dead = true
		died.emit(self, is_boss, gear_reward)
		queue_free()


## Select one of the five stage-specific boss patterns and advance its timers.
func _run_stage_ability(delta: float, player: Node2D, direction: float) -> void:
	# Each stage index selects one robot pattern; timers are shared between patterns.
	_special_timer -= delta
	_jump_timer = maxf(_jump_timer - delta, 0.0)
	match stage_id:
		0:
			_run_charge_ability(delta, direction, 340.0, 3.2)
		1:
			velocity.x = direction * move_speed
			if is_on_floor() and _special_timer <= 0.0:
				var landing_x := global_position.x + direction * 190.0
				landing_x = clampf(landing_x, -500.0, 500.0)
				_show_landing_telegraph(
					Vector2(landing_x, global_position.y + 24.0),
					150.0,
					1.05,
					Color(1.0, 0.68, 0.16)
				)
				velocity.y = -540.0
				velocity.x = direction * 190.0
				_special_timer = 3.1
		2:
			velocity.x = direction * move_speed
			if _special_timer <= 0.0 and player != null:
				_fire_fan(player, 3, 0.22, 250.0, 16.0)
				_special_timer = 2.8
		3:
			velocity.x = direction * move_speed
			_shield_cycle = fmod(_shield_cycle + delta, 6.5)
			var was_shielded := _shielded
			_shielded = _shield_cycle > 4.4
			$Visual.color = Color(0.3, 0.72, 1.0) if _shielded else _base_color
			if _shielded and not was_shielded:
				_spawn_particle_burst(global_position, Color(0.32, 0.78, 1.0), 16)
				_show_radius_telegraph(global_position, 54.0, 0.35, Color(0.32, 0.78, 1.0))
			if _slam_windup_left > 0.0:
				_slam_windup_left = maxf(_slam_windup_left - delta, 0.0)
				velocity.x = 0.0
				if _slam_windup_left <= 0.0:
					_slam_attack(player, 150.0, 22.0)
					_show_radius_telegraph(
						global_position,
						150.0,
						0.28,
						Color(1.0, 0.24, 0.12)
					)
					_spawn_particle_burst(
						global_position + Vector2(0.0, 18.0),
						Color(1.0, 0.32, 0.12),
						30
					)
			elif _special_timer <= 0.0:
				_slam_windup_left = 0.78
				_special_timer = 4.0
				velocity.x = 0.0
				_show_radius_telegraph(
					global_position,
					150.0,
					_slam_windup_left,
					Color(1.0, 0.24, 0.12)
				)
		4:
			if is_on_floor() and _jump_timer <= 0.0:
				velocity.y = -500.0
				_jump_timer = 5.0
			if _dash_time_left > 0.0:
				_dash_time_left = maxf(_dash_time_left - delta, 0.0)
				velocity.x = _dash_direction * 390.0
			else:
				velocity.x = direction * move_speed
				if _special_timer <= 0.0:
					if player != null:
						_fire_fan(player, 5, 0.32, 285.0, 20.0)
					_dash_direction = direction if not is_zero_approx(direction) else 1.0
					_dash_time_left = 0.5
					_special_timer = 3.0


## Keep the selected direction fixed until the short charge dash has ended.
func _run_charge_ability(
	delta: float,
	direction: float,
	charge_speed: float,
	cooldown: float
) -> void:
	# Keep the chosen charge direction fixed until the short dash has ended.
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)
		velocity.x = _dash_direction * charge_speed
		return
	velocity.x = direction * move_speed
	if _special_timer <= 0.0:
		_dash_direction = direction if not is_zero_approx(direction) else 1.0
		_dash_time_left = 0.55
		_special_timer = cooldown


func _landing_shockwave(player: Node2D) -> void:
	# The landing ring is visual telegraphing; damage is limited to its horizontal lane.
	_show_radius_telegraph(global_position + Vector2(0.0, 20.0), 150.0, 0.3, Color(1.0, 0.68, 0.16))
	_spawn_particle_burst(global_position + Vector2(0.0, 20.0), Color(1.0, 0.68, 0.16), 26)
	if player != null and absf(player.global_position.x - global_position.x) < 150.0:
		if player.has_method("take_damage"):
			player.call("take_damage", contact_damage * 1.4)


func _slam_attack(player: Node2D, radius: float, damage: float) -> void:
	if player == null or global_position.distance_to(player.global_position) > radius:
		return
	if player.has_method("take_damage"):
		player.call("take_damage", damage)


## Spawn evenly spaced projectiles aimed around the direction from boss to player.
func _fire_fan(player: Node2D, count: int, spread: float, speed: float, damage: float) -> void:
	# Spawn evenly spaced projectiles around the direction from this boss to the player.
	if player == null:
		return
	var base_direction := (player.global_position - global_position).normalized()
	var middle := float(count - 1) * 0.5
	for projectile_index in count:
		var offset := (float(projectile_index) - middle) * spread
		var projectile := PROJECTILE_SCENE.instantiate() as ScrapProjectile
		if projectile == null:
			continue
		projectile.configure(base_direction.rotated(offset), speed, damage, _base_color)
		projectile.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", projectile)


## Draw a growing lane warning for a boss landing before its shockwave.
func _show_landing_telegraph(
	center: Vector2,
	half_width: float,
	duration: float,
	tint: Color
) -> void:
	# Draw a long landing lane that grows and fades before the boss lands.
	var effect_root := get_tree().current_scene
	if effect_root == null:
		return

	var warning := Node2D.new()
	warning.z_index = 2
	effect_root.add_child(warning)
	warning.global_position = center
	var fill := Polygon2D.new()
	fill.color = Color(tint.r, tint.g, tint.b, 0.22)
	fill.polygon = PackedVector2Array([
		Vector2(-half_width, -10.0),
		Vector2(half_width, -10.0),
		Vector2(half_width, 10.0),
		Vector2(-half_width, 10.0)
	])
	warning.add_child(fill)
	var outline := Line2D.new()
	outline.width = 4.0
	outline.default_color = tint
	outline.points = PackedVector2Array([
		Vector2(-half_width, -10.0),
		Vector2(half_width, -10.0),
		Vector2(half_width, 10.0),
		Vector2(-half_width, 10.0),
		Vector2(-half_width, -10.0)
	])
	warning.add_child(outline)
	_fade_warning(warning, duration)


## Draw and fade a circular warning used for shields and area attacks.
func _show_radius_telegraph(center: Vector2, radius: float, duration: float, tint: Color) -> void:
	# Share the same fade animation for circular shield and slam warnings.
	var effect_root := get_tree().current_scene
	if effect_root == null:
		return

	var warning := Node2D.new()
	warning.z_index = 2
	effect_root.add_child(warning)
	warning.global_position = center
	warning.scale = Vector2(0.2, 0.2)
	var circle := _circle_points(radius, 40)
	var fill := Polygon2D.new()
	fill.color = Color(tint.r, tint.g, tint.b, 0.14)
	fill.polygon = circle
	warning.add_child(fill)
	circle.append(circle[0])
	var outline := Line2D.new()
	outline.width = 4.0
	outline.default_color = tint
	outline.points = circle
	warning.add_child(outline)
	_fade_warning(warning, duration)


func _fade_warning(warning: Node2D, duration: float) -> void:
	var tween := warning.create_tween()
	tween.tween_property(warning, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(warning, "modulate:a", 0.0, duration)
	tween.tween_callback(warning.queue_free)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in segments:
		var angle := TAU * float(point_index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


## Spawn a one-shot impact burst and release it after its finished signal.
func _spawn_particle_burst(effect_position: Vector2, tint: Color, count: int) -> void:
	# Create a one-shot impact burst and free it when the particle system finishes.
	var effect_root := get_tree().current_scene
	if effect_root == null:
		return

	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 230.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.color = tint
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.texture = _make_particle_texture()
	effect_root.add_child(particles)
	particles.global_position = effect_position
	# The particle node owns its lifetime and removes itself after its burst completes.
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _make_particle_texture() -> Texture2D:
	# Generate a small soft-edged texture so impact particles need no external asset.
	var texture_size := 8
	var image := Image.create_empty(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	for y in texture_size:
		for x in texture_size:
			var distance := Vector2(x - 3.5, y - 3.5).length() / 4.0
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _check_player_collision() -> void:
	# Apply contact damage at most once per cooldown even if several slide collisions occur.
	if _contact_cooldown > 0.0:
		return
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider() as Node2D
		if collider != null and collider.is_in_group("player"):
			collider.call("take_damage", contact_damage)
			_contact_cooldown = 0.9
			return


func _stage_color(index: int) -> Color:
	# Keep robot body colors aligned with the five stage identities.
	var colors := [
		Color(0.92, 0.38, 0.2),
		Color(0.9, 0.68, 0.18),
		Color(0.22, 0.82, 0.72),
		Color(0.42, 0.62, 0.92),
		Color(0.86, 0.16, 0.32)
	]
	return colors[clampi(index, 0, colors.size() - 1)]


## Return the silhouette polygon assigned to the requested later-stage boss.
func _stage_polygon(index: int) -> PackedVector2Array:
	# Return a distinct silhouette for each later-stage boss.
	match index:
		1:
			return PackedVector2Array([
				Vector2(-18, -30),
				Vector2(18, -30),
				Vector2(27, 12),
				Vector2(12, 25),
				Vector2(-12, 25),
				Vector2(-27, 12)
			])
		2:
			return PackedVector2Array([
				Vector2(-30, -17),
				Vector2(-22, -30),
				Vector2(22, -30),
				Vector2(30, -17),
				Vector2(30, 17),
				Vector2(22, 30),
				Vector2(-22, 30),
				Vector2(-30, 17)
			])
		3:
			return PackedVector2Array([
				Vector2(-26, -26),
				Vector2(26, -26),
				Vector2(34, -10),
				Vector2(26, 0),
				Vector2(34, 10),
				Vector2(26, 26),
				Vector2(-26, 26),
				Vector2(-34, 10),
				Vector2(-26, 0),
				Vector2(-34, -10)
			])
		4:
			return PackedVector2Array([
				Vector2(-28, -28),
				Vector2(-9, -20),
				Vector2(0, -35),
				Vector2(9, -20),
				Vector2(28, -28),
				Vector2(20, -4),
				Vector2(35, 0),
				Vector2(20, 8),
				Vector2(28, 28),
				Vector2(0, 20),
				Vector2(-28, 28),
				Vector2(-20, 8),
				Vector2(-35, 0),
				Vector2(-20, -4)
			])
		_:
			return PackedVector2Array([
				Vector2(-22, -24),
				Vector2(22, -24),
				Vector2(30, 0),
				Vector2(20, 24),
				Vector2(-20, 24),
				Vector2(-30, 0)
			])
