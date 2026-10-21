extends BossRobot

enum AttackMode { RADIAL_VOLLEY, SNIPER_SERIES, FALLING_BULLETS }
enum SniperPhase { NONE, TELEGRAPH, BETWEEN_SHOTS }

var _next_attack: int = AttackMode.RADIAL_VOLLEY
var _second_burst_delay: float = 0.0
var _burst_phase: float = 0.0
var _sniper_phase: int = SniperPhase.NONE
var _sniper_time_left: float = 0.0
var _sniper_shots_remaining: int = 0
var _sniper_target: Vector2
var _sniper_beam: Line2D


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	if _second_burst_delay > 0.0 or _sniper_phase != SniperPhase.NONE:
		return
	begin_major_attack()


## Cycle radial volleys, five delayed predictive sniper shots, and an arcing bullet rain.
func _execute_major_attack(player: Node2D, _direction: float) -> void:
	match _next_attack:
		AttackMode.RADIAL_VOLLEY:
			_fire_radial_burst(_burst_phase)
			_burst_phase += PI / 24.0
			_second_burst_delay = 0.48
		AttackMode.SNIPER_SERIES:
			_sniper_shots_remaining = 5
			_begin_sniper_shot(player)
		AttackMode.FALLING_BULLETS:
			_fire_bullet_rain()
	_next_attack = (_next_attack + 1) % 3


## Advance delayed bursts and sniper telegraphs while Ripsaw holds its firing position.
func _update_custom_motion(delta: float, player: Node2D, _direction: float) -> void:
	velocity.x = 0.0
	if _second_burst_delay > 0.0:
		_second_burst_delay -= delta
		if _second_burst_delay <= 0.0:
			_fire_radial_burst(_burst_phase)
			_burst_phase += PI / 24.0
	_update_sniper_series(delta, player)


## Fire a short-lived collision area after each 0.4-second red beam warning.
func _update_sniper_series(delta: float, player: Node2D) -> void:
	match _sniper_phase:
		SniperPhase.NONE:
			return
		SniperPhase.TELEGRAPH:
			_sniper_time_left -= delta
			if _sniper_time_left > 0.0:
				return
			_fire_sniper_shot()
			_sniper_shots_remaining -= 1
			if _sniper_shots_remaining <= 0:
				_sniper_phase = SniperPhase.NONE
				return
			_sniper_phase = SniperPhase.BETWEEN_SHOTS
			_sniper_time_left = 0.12
		SniperPhase.BETWEEN_SHOTS:
			_sniper_time_left -= delta
			if _sniper_time_left <= 0.0:
				_begin_sniper_shot(player)


## Aim one beam at the player's estimated position 0.4 seconds ahead.
func _begin_sniper_shot(player: Node2D) -> void:
	if player == null:
		_sniper_phase = SniperPhase.NONE
		return
	_sniper_target = player.global_position
	if player is CharacterBody2D:
		_sniper_target += player.velocity * 0.4
	_sniper_target.x = clampf(_sniper_target.x, -490.0, 490.0)
	_sniper_target.y = clampf(_sniper_target.y, -350.0, 370.0)
	_show_sniper_beam()
	_sniper_phase = SniperPhase.TELEGRAPH
	_sniper_time_left = 0.4


## Convert the active beam's end point into a brief instantiated damaging area.
func _fire_sniper_shot() -> void:
	if is_instance_valid(_sniper_beam):
		_sniper_beam.queue_free()
	_sniper_beam = null
	spawn_circle_hazard(
		_sniper_target,
		26.0,
		Color(1.0, 0.28, 0.3, 0.9),
		attack_damage * 1.2,
		Vector2.ZERO,
		0.16
	)


## Build a pale-red direct line from Ripsaw to the predicted sniper impact point.
func _show_sniper_beam() -> void:
	if is_instance_valid(_sniper_beam):
		_sniper_beam.queue_free()
	var arena := get_tree().current_scene
	if arena == null:
		return
	var beam := Line2D.new()
	beam.width = 5.0
	beam.default_color = Color(1.0, 0.34, 0.38, 0.58)
	beam.points = PackedVector2Array([global_position, _sniper_target])
	beam.z_index = 3
	arena.add_child(beam)
	_sniper_beam = beam


## Fire evenly spaced moving shapes in every direction for a readable two-beat pattern.
func _fire_radial_burst(phase: float) -> void:
	for bullet_index in 24:
		var angle := TAU * float(bullet_index) / 24.0 + phase
		var direction := Vector2(cos(angle), sin(angle))
		spawn_circle_hazard(global_position, 9.0, Color(0.34, 0.92, 0.85), attack_damage, direction * 265.0, 3.8)


## Launch fifty arcing bullets upward so gravity turns the arena into a falling dodge pattern.
func _fire_bullet_rain() -> void:
	for _bullet_index in 75:
		var horizontal_speed := randf_range(-320.0, 320.0)
		var upward_speed := randf_range(-1800.0, -1000.0)
		spawn_circle_hazard(
			global_position + Vector2(randf_range(-22.0, 22.0), -18.0),
			8.0,
			Color(0.3, 0.86, 0.94, 0.9),
			attack_damage * 0.65,
			Vector2(horizontal_speed, upward_speed),
			4,
			Vector2(0.0, 920.0)
		)
