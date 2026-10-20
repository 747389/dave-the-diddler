extends BossRobot

var _pattern_index: int = 0
var _followup_delay: float = 0.0


func _try_start_attack(_player: Node2D, _direction: float) -> void:
	begin_major_attack()


## Flash-step, then select the next radial, wall, or mixed attack beat.
func _execute_major_attack(player: Node2D, _direction: float) -> void:
	flash_step_toward(player)
	match _pattern_index % 3:
		0:
			_fire_final_radial_burst(30, 300.0)
			_followup_delay = 0.5
		1:
			_spawn_final_walls()
			_followup_delay = 0.65
		2:
			_fire_final_radial_burst(18, 340.0)
			_spawn_final_walls()
	_pattern_index += 1


func _update_custom_motion(delta: float, _player: Node2D, direction: float) -> void:
	if _followup_delay > 0.0:
		_followup_delay -= delta
		if _followup_delay <= 0.0:
			if _pattern_index % 3 == 1:
				_fire_final_radial_burst(30, 320.0)
			else:
				_spawn_final_walls()
	velocity.x = direction * move_speed * 0.65


## Combine fast all-direction shots and paired wall panels into a final multi-beat attack.
func _fire_final_radial_burst(count: int, speed: float) -> void:
	for bullet_index in count:
		var angle := TAU * float(bullet_index) / float(count) + float(_pattern_index) * 0.11
		var direction := Vector2(cos(angle), sin(angle))
		spawn_circle_hazard(global_position, 10.0, Color(1.0, 0.22, 0.42), attack_damage, direction * speed, 3.6)


func _spawn_final_walls() -> void:
	var wall_tint := Color(1.0, 0.14, 0.25, 0.95)
	spawn_rectangle_hazard(Vector2(510.0, 45.0), Vector2(54.0, 780.0), wall_tint, attack_damage, Vector2(-500.0, 0.0), 2.2)
	spawn_rectangle_hazard(Vector2(-510.0, 45.0), Vector2(54.0, 780.0), wall_tint, attack_damage, Vector2(500.0, 0.0), 2.2)
