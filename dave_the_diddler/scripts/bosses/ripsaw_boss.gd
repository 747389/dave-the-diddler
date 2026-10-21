extends BossRobot

var _second_burst_delay: float = 0.0
var _burst_phase: float = 0.0


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	begin_major_attack()


func _execute_major_attack(_player: Node2D, _direction: float) -> void:
	_fire_radial_burst(_burst_phase)
	_burst_phase += PI / 24.0
	_second_burst_delay = 0.48


func _update_custom_motion(delta: float, _player: Node2D, direction: float) -> void:
	if _second_burst_delay > 0.0:
		_second_burst_delay -= delta
		if _second_burst_delay <= 0.0:
			_fire_radial_burst(_burst_phase)
			_burst_phase += PI / 24.0
	velocity.x = direction * move_speed * 0.45


## Fire evenly spaced moving shapes in every direction for a readable two-beat pattern.
func _fire_radial_burst(phase: float) -> void:
	for bullet_index in 24:
		var angle := TAU * float(bullet_index) / 24.0 + phase
		var direction := Vector2(cos(angle), sin(angle))
		spawn_circle_hazard(global_position, 9.0, Color(0.34, 0.92, 0.85), attack_damage, direction * 265.0, 3.8)
